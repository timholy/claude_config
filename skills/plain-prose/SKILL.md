---
description: Rewrite a package's prose (docstrings, comments, docs pages, README) so it states what the code is and does now, in plain language, at the length the reader needs
model: opus
effort: medium
---

Rewrite the prose in a package so that it reads as if written by someone who
has only the repository in front of them. The argument (`$ARGUMENTS`) may be a
file, a directory, or a list of paths; if omitted, cover the whole package:
`src/`, `ext/`, `test/`, `docs/src/`, `README.md`, and any sibling subdir
packages in a monorepo. Skip generated files, golden/expected fixtures, and
anything under `assets/` except where step 3 proposes removing it.

This is a prose-only pass. Do not change code, identifiers, signatures,
behavior, or test assertions. The only non-prose edits permitted are those
needed to keep a docs build working after a page or asset removal approved in
step 3.

Before starting, read `~/.claude/rules/code-comments.md` and the "Text"
section of `~/.claude/CLAUDE.md`. They define the standard; this skill is the
procedure for applying it after the fact.

## Why this pass exists

Prose written while working from a plan, a review, or a debugging session
tends to carry that context with it: it argues for decisions, addresses a
reviewer, records what the code used to do, describes call sites that live
elsewhere, and repeats the same justification in every sibling. None of that
helps a reader who arrives later. This pass strips it out, rewording and
shortening in a single sweep over each file.

## 1. Scope and baseline

List the files in scope. If `docs/make.jl` exists, note the page list and
asset references so step 4 can verify the build. Require a clean working
tree so the final diff contains only this pass's edits.

## 2. Rewrite

Work file by file. For each docstring, comment block, or Markdown section,
first decide what it should cover (2b), then write it in plain wording (2a).

### 2a. Wording

Replace:

- **Jargon and metaphor** with the plain verb or noun. "fails loud with an
  `InexactError`" → "throws an `InexactError`"; "silently truncating" →
  "being truncated"; "vocabulary" (for a set of types) → "types";
  "discipline" → nothing, or "contract"; "mechanical layer" → "generated
  layer"; "degrades to" → "falls back to"; "plumbing", "footgun",
  "swallowed", "mirroring", "sklearn-flavored" → the literal meaning.
- **Slogans**, especially bold ones ("**The data says who owns it.**"), with
  the fact they summarize, in a normal sentence.
- **Analogies to other projects** ("following the same split used by libgit2
  and `sqlite3_free`") with nothing, unless compatibility with that project is
  an actual requirement.
- **Intensifiers and reassurance** with nothing: "genuine", "real",
  "actually", "just", "small", "clear", "actionable", "exactly", "on purpose",
  "deliberately", "correctly so", "not a bug", "not a gap".
- **History and planning language** with present-tense fact: "today's
  semantics, unchanged", "historical", "formerly", "pre-flag", "still", "new",
  "existing", "for the record", "rejected alternative", "as planned", "the
  round-2 report", "the sweep", "an upstream fix is in progress". A rejected
  design becomes "X is not supported" plus the one-sentence reason, if the
  reason protects a future editor from re-adding it.
- **Commentary addressed to a reviewer** with nothing: "The real test:",
  "verified by probe, not assumed", "pinned rather than silently assumed
  safe", "this whole function is a workaround for …".
- **Rhetorical contrast** ("X — never Y", "X, not Y" where Y is a strawman
  nobody proposed) with the plain statement of X. Keep "X rather than Y" when
  Y is the consequence a reader would otherwise expect ("throws rather than
  truncating").
- **Em-dash chains** with separate sentences or a colon.
- **Section titles named after process** ("Where they sit in the layer plan")
  with titles named after content ("Architecture").

Use American spelling.

### 2b. Length

The target for each unit of prose is the length a competent reader needs to
use the code correctly, and no more.

**Docstrings.** Keep: the signature line, what the function returns or
produces, what it requires of its inputs, what it rejects or throws, and any
contract the caller must honor (ownership, who frees, layout such as
column-major, thread-safety). For an internal helper this is usually one to
three sentences. Remove:

- descriptions of *other* functions, call sites, or "the two places that rely
  on this";
- field-by-field restatement of a struct whose definition is visible in the
  same file;
- the rationale for why a parameter is passed in rather than hard-coded, or
  why recognition is by shape rather than by package;
- enumerations of cases that do not occur ("no known output produces this");
- boilerplate repeated across siblings ("Target-independent: operates on
  `ABIInfo` only"); if it matters, say it once in a file-header comment;
- chains of `(see X for the rationale)` pointing at a rationale that was
  itself removed.

**Comments.** One line stating the invariant or the non-obvious reason; the
code states the mechanism. A comment that paraphrases the next line goes.
A multi-paragraph comment explaining why a branch exists becomes one
sentence stating the condition it handles.

**Test comments.** One line naming what the testset verifies. No "the same
pattern any Julia caller would use", no explanation of the fixture's origin.

**Docs pages.** Propose, but do not perform without approval: merging a page
that re-explains types already documented on another page; removing a
diagram that restates a struct layout shown in a code block; deleting
subsections that only justify a design. Present each as "page/asset → what
would absorb it → what is lost."

**Preserve, even when shortening**, anything in these categories — condense
the wording, but do not drop the content:

- an invariant a future editor would otherwise break ("`dims` precedes
  `data`; the C emitter depends on this order");
- an issue or PR reference that records context the code cannot (`# see #123`),
  including upstream issues that mark a workaround as removable once they
  ship — these are real TODO items; keep them terse, but keep them;
- a hazard: a view that must not outlive its buffer, a function that must not
  be called twice, a size limit that throws;
- `@ref` targets, doctests, and cross-references that the docs build needs;
- warnings in user-facing docs about behavior that differs from what a user
  would assume (e.g. a numpy array must be Fortran-contiguous).

## 3. Review with the user

Present: the `git diff --stat`; the list of docs-page/asset proposals
awaiting a decision; and a **judgment-call list** of removed passages that
contained information (not just wording) — one line each, so the user can
ask for any of them to be restored. Deleted issue/PR references and deleted
hazard warnings go at the top of that list. **[pause for approval]** Then
apply approved page/asset changes (updating `docs/make.jl` accordingly) and
restore anything the user asked for.

## 4. Verify

- Confirm no code changed: `git diff` should touch only comment lines,
  docstring bodies, Markdown, and (if approved) `docs/make.jl` and assets.
  Spot-check any hunk that is not obviously prose.
- If a docstring was removed entirely, make sure nothing still links to it
  with `@ref`, and that the symbol is not listed in a `@docs` block.
- If `docs/make.jl` exists, build the docs (`julia --project=docs docs/make.jl`)
  and confirm no missing-docs or cross-reference warnings were introduced.
  If doctests live in the test suite rather than the docs build, run them.

## 5. Commit and report

Commit once, with a subject such as "Simplify and condense prose". Report
lines removed vs. added; the docs proposals and their outcomes; the
judgment-call list with what the user decided; and any passage you left
alone because you could not tell whether it was history or a live
constraint, so the user can resolve it.
