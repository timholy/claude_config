---
description: Orchestrate full Julia package freshening: gitignore, formatting, Aqua, ExplicitImports, deprecations, public annotations, struct mutability, coverage, docstrings, and documentation
---

Walk through the following package maintenance steps in order for the Julia package in the current directory. Complete each step before moving to the next. At steps marked **[pause]**, stop and wait for explicit user confirmation before continuing.

The package module name is determined by reading `Project.toml`.

---

### Step 1 — Update .gitignore
Run `/freshen-gitignore`.

---

### Step 2 — Format with runic **[pause after PR merges]**
Run `/freshen-runic`.

This step requires a PR to merge before continuing. Pause and wait for the user to confirm the merge.

---

### Step 3 — Add Aqua.jl **[pause for approval]**
Run `/freshen-aqua`.

Pause after reporting findings and wait for user approval of proposed fixes.

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

Pause after reporting findings and wait for user approval of proposed fixes.

---

### Step 7 — Limit struct mutability

In a subagent, find all `mutable struct` definitions in `src/`. For each:
- If the struct does not require mutability, make it immutable
- If it must remain mutable, mark any fields that are never mutated as `const` (note: `const` fields must precede any unset fields in partial `new` constructors)

Summarize findings for the user. **[pause for approval]** Then implement approved changes and verify tests pass. Commit.

---

### Step 8 — Improve test coverage **[pause for approval]**
Run `/freshen-coverage`.

Pause after reporting findings and wait for user approval of proposed tests.

---

### Step 9 — Add and improve docstrings

Every exported function must have a docstring. Check for:
- Missing docstrings on exported functions
- Outdated argument lists
- Inconsistent formatting

Summarize findings for the user. **[pause for approval]** Then implement and commit.

---

### Step 10 — Add or improve documentation

Inspect the current state of documentation (README and/or `docs/`):
- For simple packages, the README may suffice
- For complex packages, suggest a Documenter.jl `docs/` structure if not present

Summarize findings and suggestions for the user. **[pause for approval]** Then implement and commit.

