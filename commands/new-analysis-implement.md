---
name: new-analysis-implement
description: >
  Use this skill when the user wants to implement the next step of a planned analysis project.
  Triggers only on an explicit `/new-analysis-implement`. This skill reads the plan, implements
  exactly one chunk, updates the plan, and prepares a clean handoff for the next session.
  Only use this skill when an ANALYSIS_PLAN.md exists in the project and the user wants to make
  progress — do not implement ad hoc without it.
# Recommended invocation: opus model, /effort medium
---

# New Analysis Implement

You are the implementation engine for a planned analysis project. You work one chunk at a time,
maintain the plan as persistent state, and hand off cleanly at the end of each session so the
next session can begin without any context from this one.

## Step 1: Orient

Read the following files before doing anything else:

1. **`ANALYSIS_PLAN.md`** — the full plan. Identify:
   - The project maturity target (`script` / `package` / `releasable-package`)
   - The package name and whether this extends an existing `dev`'d package
   - The next chunk with status `not-started` whose dependencies are all `complete`
   - Any open questions that might affect your work
2. **`ANALYSIS_SESSION.md`** (if it exists) — the previous session's handoff note.
   Read this to understand decisions made in prior sessions: naming conventions, data
   structures chosen, unexpected findings, known issues.

If `ANALYSIS_PLAN.md` does not exist, stop and tell the user to run `/new-analysis-plan` first.

If all chunks are `complete`, congratulate the user and suggest they review the session log
for a summary of what was built.

## Step 2: State the Plan

Before writing any code, tell the user:

- Which chunk you are about to implement (ID and name)
- What you expect it to take as input and produce as output
- What verification strategy you will use and why
- Any concerns or ambiguities you've noticed

Wait briefly — give the user a chance to redirect before you begin. A short "does this look
right?" is appropriate. Do not wait for explicit confirmation on simple chunks; use judgment.

## Step 3: Implement

Implement the chunk. The maturity target governs several decisions below — read it from the
plan and apply the corresponding behavior throughout.

### Code placement

**For `script` target:**
- Write code directly in scripts or notebooks in the project root or a `scripts/` folder
- No package structure required

**For `package` and `releasable-package` targets:**
- Analysis logic (functions, types, constants) belongs in `src/` (or the language equivalent)
- Scripts that run the analysis belong in `scripts/` and should be thin:
  import the package, call functions, save outputs
- Tests belong in `test/` or `tests/` and must be runnable by the standard test runner
- **Never write substantive logic in a script that belongs in the package**

### Code quality

- Write in the project's specified language and style
- Prefer explicit over clever; this code will be read and modified by others
- Add a docstring or comment block to every public function describing its contract:
  what it expects, what it returns, what it assumes
- For `releasable-package` targets: docstrings must be complete and follow the language
  convention (Julia: `"""..."""` above the function; Python: NumPy or Google style;
  R: roxygen2; MATLAB: leading comment block)
- Do not add dependencies not already in the environment without flagging it to the user

### Verification (moderate stance)

Apply the following decision logic for each chunk:

**Write tests when:**
- The chunk implements an algorithm, transformation, or calculation with a knowable correct output
- Reference values exist (analytical solution, published result, prior implementation)
- The logic is complex enough that silent regressions are plausible
- The chunk will be called by other chunks (i.e., its correctness is load-bearing)

**Document rationale instead of writing tests when:**
- The output is inherently visual (plots, rendered outputs) — note "requires manual review"
- The correct answer is genuinely unknown until the analysis runs (truly exploratory work)
- The chunk is a thin wrapper around a well-tested library with no custom logic

**Test portability — required for `package` and `releasable-package` targets:**

Committed tests must be **portable**: they must pass on any machine, without access
to external data files, downloaded datasets, or outputs produced by a prior analysis run.

- **Prefer synthetic ground-truth fixtures**: construct small in-memory inputs whose
  correct outputs can be computed analytically, by a simpler reference formula, or by
  inspection. Encode both the input and the expected output directly in the test file.
- **Validate on real data during development, but do not commit that as a test.**
  Running a function on your actual dataset to sanity-check it is good practice; turning
  that run into a committed test that opens a file outside the repo is not.
- **For I/O functions**, construct a minimal in-memory or in-repo fixture (a short string
  literal, a tiny synthetic array written to a `tempname()` / `tmp_path`) rather than
  pointing at a real data file.
- **For algorithms**, if an exact analytical answer exists, test against it; if not,
  test structural properties (monotonicity, symmetry, conservation law, round-trip
  invertibility) that hold for any valid input.

**In all cases:**
- Add at least lightweight assertions (input shape, type checks, non-null returns) even
  where full tests aren't warranted
- Verify behavior on real or representative data during development before marking a
  chunk complete, but record that verification in the session notes, not in the test suite
- For `package`/`releasable-package` targets: the portable test runner must pass cleanly
  before the chunk is marked `complete` — not just the new tests, but the full suite

**Testing approach and location by language:**

| Language | Framework | Location | Run command |
|---|---|---|---|
| Julia | `Test` stdlib: `@test`, `@testset` | `test/runtests.jl` | `] test` |
| Python | `pytest` | `tests/test_*.py` | `pytest` |
| R | `testthat` preferred; `stopifnot()` inline if project doesn't use it | `tests/testthat/` | `R CMD check` or `testthat::test_dir()` |
| MATLAB | `matlab.unittest` preferred; `assert()` inline if not used | `tests/Test*.m` | `runtests("tests")` |

### Scope discipline

- Implement **only** the current chunk
- If you notice problems in adjacent code while working, record them in the plan's
  Open Questions section — do not fix them now
- If the chunk turns out to be larger than expected, implement the core logic and
  flag the remainder as a new sub-chunk in the plan

## Step 4: Update the Plan

After implementation, update `ANALYSIS_PLAN.md`:

1. Change the chunk's `Status` from `not-started` → `complete` (or `blocked` if you hit
   an unresolvable issue)
2. Fill in the chunk's `Notes` field with:
   - Any decisions made during implementation (e.g., "chose sparse matrix format for
     memory reasons")
   - Any deviations from the original plan
   - Anything the next chunk's implementer needs to know
3. If you created new chunks (scope split or discovered work), add them with status
   `not-started` in the correct dependency order
4. Add any new unresolved issues to `Open Questions`
5. Append a one-paragraph entry to the `Session Log`:
   ```
   **Session [date]**: Implemented CHUNK-XXX ([name]). [1–2 sentences on what was built
   and any notable decisions.] Next up: CHUNK-XXX ([name]).
   ```

## Step 5: Write the Session Handoff

Write (or overwrite) `ANALYSIS_SESSION.md` with a handoff note for the next session.
This file should be self-contained — assume the next session has no memory of this one.

```markdown
# Session Handoff — [date]

## Project maturity target
[`script` / `package` / `releasable-package`] — [package name, or "n/a"]

## What was just completed
CHUNK-XXX: [name]
[2–3 sentences describing what was implemented and how it works]

## Key decisions made
- [Decision and rationale]
- [Decision and rationale]

## State of the codebase
- Files created or modified: [list]
- Package loads cleanly: [yes / not applicable]
- Test suite passes: [yes / not applicable / blocked — see below]
- Entry point(s): [e.g., "run `julia scripts/reproduce_fig1.jl` to execute end to end"]
- Known issues: [or "none"]

## Next chunk
CHUNK-XXX: [name]
[Brief description of what it needs to do and what inputs it will use]

## Watch out for
[Any gotchas, fragile assumptions, or things the next session should know before touching the code]
```

## Step 6: Close the Session

Tell the user:

1. What was completed and what the verification showed
2. Whether the full test suite passes (for package targets)
3. A one-line preview of the next chunk

Then explicitly invite the user to review the work before moving on. This is the ideal
moment to do so: the code is fresh, you have full context, and changes are cheap. Say
something like:

> **Now is the best time to review these changes.** I have complete context on every
> decision made in this chunk and can explain, justify, or revise anything while it's
> still fresh. Please look over the code (including any tests), ask any questions you
> have, and suggest any improvements you'd like. We can iterate here before closing out.

Once the user is satisfied with the changes, prompt them to commit:

> When you're happy with the changes, please commit them (e.g., `git add -p && git commit`
> or via your preferred tool) so this chunk is captured as a clean, standalone unit of work.

After the user has committed (or explicitly declined), issue the handoff prompt:

> **Ready for the next session.** Please run `/clear` to reset the context window, then
> run `/new-analysis-implement` again. The plan and session notes will orient the next
> session without needing any context from this one.

If the chunk was marked `blocked` instead of `complete`, explain the blocker clearly and
suggest how the user might resolve it (manually, by revising the plan, or by asking for help)
before the next session begins.
