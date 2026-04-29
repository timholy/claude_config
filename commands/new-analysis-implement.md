---
name: new-analysis-implement
description: >
  Use this skill when the user wants to implement the next step of a planned analysis project.
  Triggers only on an explicit `/new-analysis-implement`. This skill reads the plan, implements
  exactly one chunk, updates the plan, and prepares a clean handoff for the next session.
  Only use this skill when an ANALYSIS_PLAN.md exists in the project and the user wants to make
  progress — do not implement ad hoc without it.
---

# New Analysis Implement

You are the implementation engine for a planned analysis project. You work one chunk at a time,
maintain the plan as persistent state, and hand off cleanly at the end of each session so the
next session can begin without any context from this one.

## Step 1: Orient

Read the following files before doing anything else:

1. **`ANALYSIS_PLAN.md`** — the full plan. Identify:
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

Implement the chunk. Follow these principles:

### Code quality
- Write the implementation in the project's specified language and style
- Prefer explicit over clever; this code will be read and modified by others
- Add a docstring or comment block to every function describing its contract:
  what it expects, what it returns, what it assumes
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
- The correct output is unknown until the analysis runs (genuinely exploratory work)
- The chunk is a thin wrapper around a well-tested library with no custom logic

**In all cases:**
- Add at least lightweight assertions (input shape, type checks, non-null returns) even
  where full tests aren't warranted
- Never mark a chunk complete without running it on real or representative data

**Testing approach by language:**
- Python: `pytest`, standard `assert`, or `unittest` — prefer `pytest`
- Julia: `@test` / `@testset` from `Test` stdlib — use these; they are idiomatic
- R: `testthat` if the project already uses it; otherwise inline `stopifnot()` assertions
- MATLAB: `matlab.unittest` if the project uses it; otherwise inline `assert()` calls

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

## What was just completed
CHUNK-XXX: [name]
[2–3 sentences describing what was implemented and how it works]

## Key decisions made
- [Decision and rationale]
- [Decision and rationale]

## State of the codebase
- Files created or modified: [list]
- Entry point(s): [e.g., "run `main.py` to execute the pipeline end to end"]
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
2. A one-line preview of the next chunk
3. The following prompt, word for word:

> **Ready for the next session.** Please run `/clear` to reset the context window, then
> run `/new-analysis-implement` again. The plan and session notes will orient the next
> session without needing any context from this one.

If the chunk was marked `blocked` instead of `complete`, explain the blocker clearly and
suggest how the user might resolve it (manually, by revising the plan, or by asking for help)
before the next session begins.
