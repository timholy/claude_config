#!/usr/bin/env python3
"""PostToolUse backstop: flag plan/history leakage in freshly written source.

Fires after every Edit/Write/MultiEdit. Scans the new text for the handful of
tells that recur when an agent lets planning scaffolding or change-history leak
into code comments (see rules/code-comments.md), and, if it finds any, hands a
short reminder back to the agent. Advisory only — the edit has already landed;
the agent decides whether to revise. Anything unexpected exits silently so the
hook can never obstruct editing.
"""
import json
import re
import sys

# Only source files carry code comments. Markdown/TOML/JSON/text are excluded:
# plan files (ANALYSIS_PLAN.md, session notes) legitimately discuss the plan.
CODE_EXT = {
    ".jl", ".py", ".r", ".m", ".js", ".jsx", ".ts", ".tsx",
    ".c", ".h", ".cc", ".cpp", ".cxx", ".hpp", ".rs", ".go", ".java",
}

# (label, compiled pattern). Kept tight to stay high-precision; the first group
# is all but unambiguous, the second catches the prose history-markers the
# user repeatedly has to strike out.
PATTERNS = [
    ("plan/chunk reference", re.compile(r"CHUNK-\d", re.I)),
    ("plan file reference", re.compile(r"ANALYSIS_(?:PLAN|SESSION)")),
    ('"as planned"', re.compile(r"\bas planned\b", re.I)),
    ('"Regression:" tag', re.compile(r"\bregression:", re.I)),
    ('history ("Formerly")', re.compile(r"\bformerly\b", re.I)),
    ('history ("Previously")', re.compile(r"\bpreviously\b", re.I)),
    ('history ("used to")', re.compile(r"\bused to\b", re.I)),
    ('hedge ("for now")', re.compile(r"\bfor now\b", re.I)),
]


def new_text(tool_input):
    """Collect the text this tool call introduces, across tool shapes."""
    parts = []
    if "content" in tool_input:                       # Write
        parts.append(tool_input["content"])
    if "new_string" in tool_input:                    # Edit
        parts.append(tool_input["new_string"])
    for edit in tool_input.get("edits", []):          # MultiEdit
        parts.append(edit.get("new_string", ""))
    return "\n".join(parts)


def main():
    data = json.load(sys.stdin)
    tool_input = data.get("tool_input", {})
    path = tool_input.get("file_path", "")
    dot = path.rfind(".")
    if dot < 0 or path[dot:].lower() not in CODE_EXT:
        return
    text = new_text(tool_input)
    hits = sorted({label for label, pat in PATTERNS if pat.search(text)})
    if not hits:
        return
    sys.stderr.write(
        "Possible plan/history leakage in comments of {}: {}.\n"
        "Comments should state what is true about the code now, not its history "
        "or the plan it came from (rules/code-comments.md). Re-read the new "
        "comments; revise any that only make sense to someone who watched the "
        "code being written.\n".format(path, ", ".join(hits))
    )
    sys.exit(2)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # A backstop must never block editing; stay silent on any surprise.
        pass
