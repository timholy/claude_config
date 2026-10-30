#!/usr/bin/env python3
"""Print a structural inventory of a LaTeX manuscript for the survey.

Usage: manuscript_inventory.py MAIN.tex [--section N] [--all-labels]

Follows \\input and \\include, strips comments, and prints four markdown tables:

1. Sections: words, lines, displayed equations, formal results (theorem,
   lemma, corollary, proposition, definition, conjecture), and proofs for
   every (sub)section. Compare sizes with each section's role.
2. Labels: labels cited nowhere, or cited only inside the subsection that
   defines them (with --all-labels, every label and the sections citing it).
   A displayed result that nothing later uses needs a reason to stay in the
   main text.
3. Symbol families: every base letter used in math in more than one form
   (plain, bold, \\check, \\tilde, \\bar, calligraphic, ...), with counts, the
   sections each form appears in, and its first line. A decoration does not
   keep two meanings apart for a reader.
4. Index letters: each letter used as a subscript or superscript index, the
   symbols it indexes, and how often it also appears as a quantity of its own.
   One index letter attached to symbols from two different sets (e.g. outputs
   and tape nodes), or a letter that is both an index and a quantity (v_L and
   O(L)), may have two roles.

Zero-argument macros (\\newcommand{\\bfa}{\\mathbf{a}}) are expanded before
math is parsed, so \\bfa and \\mathbf{a} are the same form.

--section N restricts tables 2-4 to labels defined in, and symbols used in,
section N and its subsections (N may be "2", "2.3", or "A").

Line numbers are file:line in the files as read. An \\input that cannot be
found is an error, because the inventory would silently omit its content.
"""
import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path

DECOR = {"check", "tilde", "widetilde", "bar", "overline", "hat", "widehat",
         "dot", "ddot", "vec", "breve", "underline", "mathring", "acute", "grave"}
FONTS = {"mathbf": "bold", "bm": "bold", "boldsymbol": "bold", "mathcal": "cal",
         "mathfrak": "frak", "mathbb": "bb", "mathsf": "sf", "mathscr": "scr",
         "mathit": "it"}
SKIPGROUP = {"mathrm", "text", "textrm", "textup", "textit", "textbf", "mbox",
             "operatorname", "label", "ref", "eqref", "pref", "peqref", "cref",
             "Cref", "autoref", "begin", "end", "emph", "tag", "hbox", "mathop"}
GREEK = set("""alpha beta gamma delta epsilon varepsilon zeta eta theta vartheta
iota kappa lambda mu nu xi pi varpi rho varrho sigma varsigma tau upsilon phi
varphi chi psi omega Gamma Delta Theta Lambda Xi Pi Sigma Upsilon Phi Psi
Omega ell""".split())
NUMBERSETS = set("RCNZQ")
MATHENVS = ("equation", "align", "gather", "multline", "eqnarray", "displaymath",
            "math", "alignat", "flalign")
DISPLAYENVS = ("equation", "align", "gather", "multline", "eqnarray", "displaymath",
               "alignat", "flalign")
RESULTENVS = ("theorem", "lemma", "corollary", "proposition", "definition", "conjecture")
REFCMDS = r"(?:ref|eqref|pref|peqref|pageref|cref|Cref|autoref|nameref|vref)"


def fail(msg):
    sys.exit(f"manuscript_inventory: {msg}")


# ---------------------------------------------------------------- reading

def strip_comment(line):
    m = re.search(r"(?<!\\)%", line)
    return line[:m.start()] if m else line


def find_input(name, here, root):
    cands = [name] if name.endswith(".tex") else [name + ".tex", name]
    for base in [here, *here.parents[:3], root, Path.cwd()]:
        for c in cands:
            p = base / c
            if p.is_file():
                return p
    return None


def read_lines(path, root, out, seen):
    path = path.resolve()
    if path in seen:
        fail(f"{path} is input more than once (cycle?)")
    seen.add(path)
    for n, raw in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        line = strip_comment(raw)
        m = re.search(r"\\(?:input|include)\s*\{([^}]+)\}", line)
        if m:
            p = find_input(m.group(1).strip(), path.parent, root)
            if p is None:
                fail(f"{path.name}:{n}: cannot find \\input{{{m.group(1)}}}")
            out.append((path.name, n, line[:m.start()]))
            read_lines(p, root, out, seen)
            out.append((path.name, n, line[m.end():]))
        else:
            out.append((path.name, n, line))


def balanced(text, i):
    """Return the end index (exclusive) of the brace group starting at text[i] == '{'."""
    depth = 0
    for j in range(i, len(text)):
        if text[j] == "{" and (j == 0 or text[j - 1] != "\\"):
            depth += 1
        elif text[j] == "}" and text[j - 1] != "\\":
            depth -= 1
            if depth == 0:
                return j + 1
    return None


def zero_arg_macros(text):
    macros = {}
    pat = re.compile(r"\\(?:re)?newcommand\*?\s*\{?\\([A-Za-z]+)\}?\s*(\[\d\])?\s*(?=\{)|"
                     r"\\def\\([A-Za-z]+)\s*(?=\{)")
    for m in pat.finditer(text):
        if m.group(2):  # takes arguments
            continue
        name = m.group(1) or m.group(3)
        end = balanced(text, m.end())
        if end:
            macros[name] = text[m.end() + 1:end - 1]
    return macros


def expand(text, macros):
    if not macros:
        return text
    pat = re.compile(r"\\(" + "|".join(sorted(map(re.escape, macros), key=len, reverse=True))
                     + r")(?![A-Za-z])")
    for _ in range(4):
        new = pat.sub(lambda m: " " + macros[m.group(1)] + " ", text)
        if new == text:
            break
        text = new
    return text


# ---------------------------------------------------------------- sections

def roman_letter(n):
    return chr(ord("A") + n - 1)


def find_sections(text):
    secs = [{"num": "front", "title": "(front matter)", "start": 0, "depth": 0}]
    sec = sub = subsub = 0
    appendix = False
    pat = re.compile(r"\\(section|subsection|subsubsection)(\*?)\s*(?:\[[^\]]*\])?\s*\{|\\appendix\b")
    for m in pat.finditer(text):
        if m.group(0).startswith("\\appendix"):
            appendix, sec = True, 0
            continue
        end = balanced(text, m.end() - 1)
        title = re.sub(r"\s+", " ", text[m.end():end - 1]).strip()
        kind, star = m.group(1), m.group(2)
        if star:
            num, depth = "*", {"section": 1, "subsection": 2, "subsubsection": 3}[kind]
        elif kind == "section":
            sec, sub, subsub, depth = sec + 1, 0, 0, 1
            num = roman_letter(sec) if appendix else str(sec)
        elif kind == "subsection":
            sub, subsub, depth = sub + 1, 0, 2
            num = f"{roman_letter(sec) if appendix else sec}.{sub}"
        else:
            subsub, depth = subsub + 1, 3
            num = f"{roman_letter(sec) if appendix else sec}.{sub}.{subsub}"
        secs.append({"num": num, "title": title, "start": m.start(), "depth": depth})
    for a, b in zip(secs, secs[1:] + [None]):
        a["end"] = b["start"] if b else len(text)
    return secs


def section_at(secs, pos):
    cur = secs[0]
    for s in secs:
        if s["start"] <= pos:
            cur = s
        else:
            break
    return cur


def in_scope(num, want):
    return want is None or num == want or num.startswith(want + ".")


# ---------------------------------------------------------------- math

def math_spans(text):
    spans = []
    env = "|".join(MATHENVS)
    pat = re.compile(r"\\begin\{(" + env + r")\*?\}|\\\[|\\\(|\$\$|(?<!\\)\$")
    i = 0
    while True:
        m = pat.search(text, i)
        if not m:
            return spans
        tok = m.group(0)
        if m.group(1):
            close = re.compile(r"\\end\{" + m.group(1) + r"\*?\}")
        else:
            close = re.compile({"\\[": r"\\\]", "\\(": r"\\\)", "$$": r"\$\$"}.get(tok, r"(?<!\\)\$"))
        e = close.search(text, m.end())
        if not e:
            return spans
        spans.append((m.end(), e.start()))
        i = e.end()


TOKEN = re.compile(r"\\[A-Za-z]+|\\.|[A-Za-z]|\d+|\S")


def tokenize(math, offset):
    return [(t.group(0), offset + t.start()) for t in TOKEN.finditer(math)]


def skip_group(toks, i):
    """Skip one argument (brace group or single token) starting at toks[i]."""
    if i >= len(toks):
        return i
    if toks[i][0] != "{":
        return i + 1
    depth = 0
    for j in range(i, len(toks)):
        if toks[j][0] == "{":
            depth += 1
        elif toks[j][0] == "}":
            depth -= 1
            if depth == 0:
                return j + 1
    return len(toks)


def parse_atom(toks, i):
    """Return (base, mods, next_i); base is None if toks[i] does not start a symbol."""
    if i >= len(toks):
        return None, (), i
    t = toks[i][0]
    if t == "{":
        base, mods, j = parse_atom(toks, i + 1)
        if base is not None and j < len(toks) and toks[j][0] == "}":
            return base, mods, j + 1
        return None, (), skip_group(toks, i)
    if t.startswith("\\"):
        name = t[1:]
        if name in DECOR or name in FONTS:
            base, mods, j = parse_atom(toks, i + 1)
            mod = name if name in DECOR else FONTS[name]
            if mod == "widetilde":
                mod = "tilde"
            if mod == "widehat":
                mod = "hat"
            return base, ((mod,) + mods if base else ()), j
        if name in SKIPGROUP:
            return None, (), skip_group(toks, i + 1)
        if name in GREEK:
            return name, (), i + 1
        return None, (), i + 1
    if len(t) == 1 and t.isalpha():
        return t, (), i + 1
    return None, (), i + 1


def form_name(base, mods):
    b = base if len(base) == 1 else "\\" + base
    return " ".join(list(mods) + [b])


def scan(toks, uses, index_uses, parent=None):
    i = 0
    while i < len(toks):
        base, mods, j = parse_atom(toks, i)
        if base is None:
            i = max(j, i + 1)
            continue
        form = form_name(base, mods)
        pos = toks[i][1]
        scripts = []
        while j < len(toks) and toks[j][0] in ("_", "^"):
            kind = toks[j][0]
            k = skip_group(toks, j + 1)
            inner = toks[j + 2:k - 1] if j + 1 < len(toks) and toks[j + 1][0] == "{" else toks[j + 1:k]
            scripts.append((kind, inner))
            j = k
        if mods == ("bb",) and base in NUMBERSETS:
            pass
        elif parent is not None and not mods and not scripts:
            index_uses[base].append((parent, pos))
        else:
            uses[base][form].append(pos)
        for kind, inner in scripts:
            if mods == ("bb",) and base in NUMBERSETS:
                continue  # dimensions, as in R^n
            if kind == "^" and len(inner) == 1 and inner[0][0] in ("T", "H", "*"):
                continue  # transpose, conjugate transpose, adjoint
            scan(inner, uses, index_uses, parent=form)
        i = j


# ---------------------------------------------------------------- report

def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("tex")
    ap.add_argument("--section", help="restrict tables 2-4 to this section number")
    ap.add_argument("--all-labels", action="store_true")
    args = ap.parse_args()

    main_path = Path(args.tex)
    if not main_path.is_file():
        fail(f"no such file: {main_path}")
    lines = []
    read_lines(main_path, main_path.resolve().parent, lines, set())
    text = "\n".join(l for _, _, l in lines)
    starts, acc = [], 0
    for _, _, l in lines:
        starts.append(acc)
        acc += len(l) + 1

    def where(pos):
        lo, hi = 0, len(starts) - 1
        while lo < hi:
            mid = (lo + hi + 1) // 2
            if starts[mid] <= pos:
                lo = mid
            else:
                hi = mid - 1
        f, n, _ = lines[lo]
        return f"{f}:{n}" if f != main_path.name else f":{n}"

    body_at = text.find("\\begin{document}")
    macros = zero_arg_macros(text[:body_at] if body_at >= 0 else text)
    secs = find_sections(text)
    want = args.section
    if want and not any(s["num"] == want for s in secs):
        fail(f"no section numbered {want!r}")

    # 1. Sections
    print(f"# Inventory of {main_path}\n")
    print("## Sections\n")
    print("| § | title | line | words | lines | displays | results | proofs |")
    print("|---|---|---|---|---|---|---|---|")
    disp_pat = re.compile(r"\\begin\{(?:" + "|".join(DISPLAYENVS) + r")\*?\}|\\\[")
    res_pat = re.compile(r"\\begin\{(?:" + "|".join(RESULTENVS) + r")\*?\}")
    for s in secs:
        chunk = text[s["start"]:s["end"]]
        if s["num"] == "front" and body_at >= 0:
            chunk = text[body_at:s["end"]]
        indent = "  " * max(s["depth"] - 1, 0)
        print(f"| {s['num']} | {indent}{s['title'][:60]} | {where(s['start'])} | {len(chunk.split())} "
              f"| {chunk.count(chr(10))} | {len(disp_pat.findall(chunk))} "
              f"| {len(res_pat.findall(chunk))} | {chunk.count(chr(92) + 'begin{proof}')} |")

    # 2. Labels
    labels = {}
    for m in re.finditer(r"\\label\{([^}]+)\}", text):
        labels[m.group(1)] = m.start()
    cites = defaultdict(list)
    for m in re.finditer(r"\\" + REFCMDS + r"\*?\{([^}]+)\}", text):
        for lab in m.group(1).split(","):
            lab = lab.strip()
            if lab in labels:
                cites[lab].append(m.start())
    print("\n## Labels\n")
    print("`local` = cited only inside the subsection that defines it (not reported for figures and tables).\n")
    print("| label | defined | § | citations | cited from § |")
    print("|---|---|---|---|---|")
    for lab, pos in sorted(labels.items(), key=lambda kv: kv[1]):
        home = section_at(secs, pos)["num"]
        if not in_scope(home, want):
            continue
        from_secs = sorted({section_at(secs, c)["num"] for c in cites[lab]},
                           key=lambda n: [s["num"] for s in secs].index(n))
        # Figures and tables are normally cited only from their own section.
        flag = ("**uncited**" if not cites[lab]
                else "**local**" if from_secs == [home] and not lab.startswith(("fig:", "tab:"))
                else "")
        if flag or args.all_labels:
            print(f"| `{lab}` {flag} | {where(pos)} | {home} | {len(cites[lab])} | {', '.join(from_secs)} |")

    # 3-4. Symbols
    uses = defaultdict(lambda: defaultdict(list))
    index_uses = defaultdict(list)
    for a, b in math_spans(text):
        scan(tokenize(expand(text[a:b], macros), a), uses, index_uses)

    def secnums(positions):
        nums = []
        for p in positions:
            n = section_at(secs, p)["num"]
            top = n.split(".")[0]
            if top not in nums:
                nums.append(top)
        return nums

    print("\n## Symbol families with more than one form\n")
    print("| family | form | uses | top-level § | first |")
    print("|---|---|---|---|---|")
    fams = [(b, forms) for b, forms in uses.items() if len(forms) > 1]
    fams.sort(key=lambda bf: (-len(bf[1]), -sum(map(len, bf[1].values()))))
    for base, forms in fams:
        if want and not any(in_scope(section_at(secs, p)["num"], want)
                            for ps in forms.values() for p in ps):
            continue
        for k, (form, ps) in enumerate(sorted(forms.items(), key=lambda kv: -len(kv[1]))):
            fam = form_name(base, ()) if k == 0 else ""
            print(f"| {fam} | `{form}` | {len(ps)} | {', '.join(secnums(ps))} | {where(ps[0])} |")

    print("\n## Index letters\n")
    print("Symbols each letter indexes (subscript or superscript), most frequent first. "
          "`as symbol` counts the letter's uses as a quantity in its own right (e.g. `O(L)`); "
          "a letter that is both an index and a quantity may have two roles.\n")
    print("| index | uses | as symbol | indexes (count) |")
    print("|---|---|---|---|")
    for idx, items in sorted(index_uses.items(), key=lambda kv: -len(kv[1])):
        if want:
            items = [(p, pos) for p, pos in items if in_scope(section_at(secs, pos)["num"], want)]
        parents = defaultdict(int)
        for p, _ in items:
            parents[p] += 1
        if len(parents) < 2:
            continue
        top = sorted(parents.items(), key=lambda kv: -kv[1])
        shown = ", ".join(f"`{p}` ({c})" for p, c in top[:14])
        more = f", +{len(top) - 14} more" if len(top) > 14 else ""
        own = [pos for pos in uses[idx][form_name(idx, ())]
               if not want or in_scope(section_at(secs, pos)["num"], want)]
        print(f"| {form_name(idx, ())} | {len(items)} | {len(own)} | {shown}{more} |")


if __name__ == "__main__":
    main()
