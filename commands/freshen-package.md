---
description: Orchestrate full Julia package freshening: gitignore, formatting, Aqua, ExplicitImports, deprecations, public annotations, struct mutability, API conventions, coverage, docstrings, and documentation
---

Walk through the following package maintenance steps for the Julia package in the current directory. The package module name is determined by reading `Project.toml`.

Before starting, check whether the repository has a file `.claude/freshen-package-status` in the repository's `.claude` folder:
- If it does not exist, create the file, writing one line per step below in the order they appear. On each line, write "status: name", where `status` is one of "TODO", "Optional", or "DONE", and `name` is the title of the step. Items in the steps below already use this format in their markdown header string.
- If it does exist, read the file and determine which items (if any) do not have status "DONE". **If no items remain, inform the user and stop executing this skill.**

Perform the next unfinished step, unless it is "optional" in which case you should ask the user for their intent, moving to the next if it is declined.

After completing a step:

- mark it "DONE" in `.claude/freshen-package-status`
- if there are unmerged changes, propose a commit message and ask whether a commit should be made
- check whether any steps remain:
  + if so, prompt the user to `/clear` the session and run `/freshen-package` again
  + if not, inform the user about the current status and ask permission to delete `.claude/freshen-package-status`

---

### Optional: design review

Run `/review-design`.

---

### Optional: API review

Run `/review-api`.

---

### TODO: update .gitignore
Run `/freshen-gitignore`.

---

### TODO: format with runic
Run `/freshen-runic`.

This step requires a PR to merge before continuing. Pause and wait for the user to confirm the merge.

---

### TODO: add Aqua.jl
Run `/freshen-aqua`.

---

### TODO: remove deprecations

Search for `@deprecate` and `Base.depwarn` in `src/`. If none are found, this task can be immediately marked as "DONE" and execution of this step finished.

For each deprecated operation found:
- Remove the deprecation
- Migrate or remove any associated tests (remove if the test's sole purpose was to verify the deprecated syntax and the new functionality is already fully covered; otherwise migrate to test the replacement)
- Update callers within the package if any

---

### TODO: add ExplicitImports.jl
Run `/freshen-explicit-imports`.

---

### TODO: limit struct mutability
Run `/limit-struct-mutability`.

---

### TODO: improve test coverage
Run `/freshen-coverage`.

---

### TODO: add and improve docstrings
Run `/freshen-docstrings`.

---

### TODO: add or improve documentation
Run `/freshen-docs`.
