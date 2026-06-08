---
description: Orchestrate full Julia package freshening: gitignore, deprecations, Aqua, ExplicitImports, struct mutability, design/API/integration reviews, generic indexing, coverage, docstrings, documentation, and formatting
---

Walk through the following package maintenance steps for the Julia package in the current directory. The package module name is determined by reading `Project.toml`.

Before starting, check whether the repository has a file `.claude/freshen-package-status` in the repository's `.claude` folder:
- If it does not exist, create the file, writing one line per step below in the order they appear. On each line, write "status: name", where `status` is one of "TODO", "Optional", or "DONE", and `name` is the title of the step. Items in the steps below already use this format in their markdown header string.
- If it does exist, read the file and determine which items (if any) do not have status "DONE". **If no items remain, inform the user and stop executing this skill.**

Perform the next unfinished step. If it is "optional" ask the user for their intent, moving to the next if it is declined.

After completing a step:

- mark it "DONE" in `.claude/freshen-package-status`
- if there are unmerged changes, propose a commit message and ask whether a commit should be made
- check whether any steps remain:
  + if so, prompt the user to `/clear` the session and run `/freshen-package` again
  + if not, inform the user about the current status and ask permission to delete `.claude/freshen-package-status`

The ordering rationale: cheap deterministic cleanup runs first to clear the deck and to handle the things the reviews would otherwise duplicate (Aqua, ExplicitImports). The three reviews then run on cleaned-up code while the user's attention is fresh — these are the highest-judgment steps. API-dependent finishing work (generic-indexing tests, coverage, docstrings, docs) runs after the reviews so it targets the settled API; generic-indexing tests come first in that group so their `src/` fixes and new tests are in place before coverage measures them. Runic formatting is last so the substantive modernization can be bundled into a small number of PRs without being interrupted by the runic step's forced merge to the default branch.

---

### TODO: update .gitignore
Run `/freshen-gitignore`.

---

### TODO: remove deprecations

Search for `@deprecate` and `Base.depwarn` in `src/`. If none are found, this task can be immediately marked as "DONE" and execution of this step finished.

For each deprecated operation found:
- Remove the deprecation
- Migrate or remove any associated tests (remove if the test's sole purpose was to verify the deprecated syntax and the new functionality is already fully covered; otherwise migrate to test the replacement)
- Update callers within the package if any

This step runs *before* the reviews because `/review-implement` may add new deprecation shims for breaking changes; those should remain in place for the current release cycle and be removed by the *next* freshening pass.

---

### TODO: add Aqua.jl
Run `/freshen-aqua`.

---

### TODO: add ExplicitImports.jl
Run `/freshen-explicit-imports`.

---

### TODO: limit struct mutability
Run `/limit-struct-mutability`.

---

### Optional: design review

Run `/review-design`. **Do not proceed to the next `/freshen-package` step until the resulting plan is implemented to completion via `/review-implement`** — re-run `/freshen-package` only after the plan is fully consumed.

---

### Optional: API review

Run `/review-api`. **Do not proceed to the next `/freshen-package` step until the resulting plan is implemented to completion via `/review-implement`** — re-run `/freshen-package` only after the plan is fully consumed.

---

### Optional: integration review

Run `/review-integration`. **Do not proceed to the next `/freshen-package` step until the resulting plan is implemented to completion via `/review-implement`** — re-run `/freshen-package` only after the plan is fully consumed.

---

### TODO: enforce generic indexing
Run `/freshen-generic-axes`.

---

### TODO: improve test coverage
Run `/freshen-coverage`.

---

### TODO: add and improve docstrings
Run `/freshen-docstrings`.

---

### TODO: add or improve documentation
Run `/freshen-docs`.

---

### TODO: format with runic
Run `/freshen-runic`.

This step requires a PR to merge before continuing. Pause and wait for the user to confirm the merge.
