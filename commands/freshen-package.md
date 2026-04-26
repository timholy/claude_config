---
description: Orchestrate full Julia package freshening: gitignore, formatting, Aqua, ExplicitImports, deprecations, public annotations, struct mutability, API conventions, coverage, docstrings, and documentation
---

Walk through the following package maintenance steps in order for the Julia package in the current directory. Complete each step before moving to the next. At steps marked **[pause]**, stop and wait for explicit user confirmation before continuing.

The package module name is determined by reading `Project.toml`.

---

### Preliminary — Design review (separate session recommended)

Before starting, suggest to the user that they run `/review-design` in a separate Claude session first. That skill reviews the package's conceptual design — type hierarchy, scope, composability, overlapping operations — and may surface changes (renaming or removing types, restructuring the export list) that would affect what is worth investing in during the steps below. It is discussion-only and produces no code changes, so it is best done before the freshening work begins.

Do not block on this — if the user wants to proceed without it, continue to Step 1.

---

### Step 1 — Update .gitignore
Run `/freshen-gitignore`.

---

### Step 2 — Format with runic **[pause after PR merges]**
Run `/freshen-runic`.

This step requires a PR to merge before continuing. Pause and wait for the user to confirm the merge. Once confirmed, ask the user to run `/compact` before continuing to Step 3.

---

### Step 3 — Add Aqua.jl **[pause for approval]**
Run `/freshen-aqua`.

Pause after reporting findings and wait for user approval of proposed fixes. Once all Aqua changes are committed, ask the user to run `/compact` before continuing to Step 4.

---

### Step 4 — Remove deprecations and bump version

Search for `@deprecate` and `Base.depwarn` in `src/`. For each:
- Remove the deprecation
- Migrate or remove any associated tests (remove if the test's sole purpose was to verify the deprecated syntax and the new functionality is already fully covered; otherwise migrate to test the replacement)
- Update callers within the package if any

Then bump the version in `Project.toml` to indicate a breaking change:
- If the major version is 0, increment the minor version (e.g., 0.3.1 → 0.4.0)
- Otherwise increment the major version

Commit the changes.

---

### Step 5 — Add `@public` annotations

Identify functions that are intended to be called via scoping (not exported, but part of the public API) and mark them `@public`.

Check the Julia lower bound in `[compat]` of `Project.toml`:

- **If the lower bound is ≥ 1.11**, use `public` directly (it is a built-in keyword).
- **If the lower bound is < 1.11**, add the following compatibility shim to the package and use `@public` instead:

```julia
macro public(ex)
    if VERSION >= v"1.11.0-DEV.469"
        args = ex isa Symbol ? (ex,) : Base.isexpr(ex, :tuple) ? ex.args : error("something informative")
        esc(Expr(:public, args...))
    else
        nothing
    end
end
```

Commit if any changes are made.

---

### Step 6 — Analyze with ExplicitImports.jl **[pause for approval]**
Run `/freshen-explicit-imports`.

Pause after reporting findings and wait for user approval of proposed fixes. Once all ExplicitImports changes are committed, ask the user to run `/compact` before continuing to Step 7.

---

### Step 7 — Review API conventions **[pause for approval]**
Run `/review-api`.

Pause after the report is presented and wait for user approval of which changes to make. After `/review-api` fully completes (including any version bump in Phase 5), ask the user to run `/compact` before continuing to Step 8.

---

### Step 8 — Limit struct mutability

In a subagent, find all `mutable struct` definitions in `src/`. For each:
- If the struct does not require mutability, make it immutable
- If it must remain mutable, mark any fields that are never mutated as `const` (note: `const` fields must precede any unset fields in partial `new` constructors)

The subagent should return a structured list: for each `mutable struct`, whether it can be made immutable, and which fields (if any) can be marked `const`. **[pause for approval]** Then implement approved changes and verify tests pass. Commit.

---

### Step 9 — Improve test coverage **[pause for approval]**
Run `/freshen-coverage`.

Pause after reporting findings and wait for user approval of proposed tests.

---

### Step 10 — Add and improve docstrings **[pause for approval]**
Run `/freshen-docstrings`.

Pause after reporting findings and wait for user approval of proposed changes.

---

### Step 11 — Add or improve documentation
Run `/freshen-docs`.

Commit changes.
