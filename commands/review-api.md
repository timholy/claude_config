---
description: Review a Julia package's public API for consistency with modern Julia conventions and idioms
---

Review the Julia package in the current working directory for API design convention issues. The goal is not to fix bugs or deprecated syntax — assume the code runs correctly on modern Julia. The goal is to identify places where the package's own API would feel surprising or inconsistent to a user who learned Julia in the modern era (1.6+), by comparison with the conventions established by Base and the standard library.

The package module name is determined from `Project.toml`.

---

## Phase 1 — Inventory the public API

Use a subagent to read all files in `src/` and build the inventory. The subagent should identify every exported or `public`-annotated function, macro, and type, recording for each function its full set of method signatures (argument names, types, and keyword arguments). Also note functions not exported but intended for `Module.name`-style use (e.g., documented but not exported).

The subagent should return a structured list — not the raw source. The main session works from this list.

---

## Phase 2 — Check each convention category

For each item in the public API, work through the following checks. For each finding, record: the function name, file and line number, the current signature or pattern, the suggested change, and whether the change would be breaking.

### 2a. Dimension arguments

Does the function operate along a dimension of an array (or similar container)? If so, check whether the dimension is passed as:
- A trailing positional integer: `f(A, 2)` — **flag**: modern Julia passes dimension as `f(A; dims=2)`, following `sum`, `maximum`, `findmax`, etc.
- A positional `Val{d}()` argument: `f(A, Val(2))` — **flag**: this was a performance workaround that is usually no longer needed; prefer `dims` keyword with `dims::Union{Int,Tuple{Vararg{Int}}}`.

Check whether the function also supports `dims` as a `Tuple` for operating over multiple dimensions simultaneously (as `sum(A; dims=(1,3))` does). If it only accepts a scalar, flag it.

### 2b. Data-first argument ordering

In Julia, the convention is: data comes first, configuration/options come after (as positional or keyword args). Flag:
- Functions where a mode, type selector, or configuration value is the *first* positional argument and data is second.
- Functions where a callable (function argument) is not in the first position when the function is reduction/transform-like — exception: `map(f, A)` puts `f` first, which is also idiomatic when the function is primary. Use judgment: is the function more like `map` (callable is the point) or more like `sort` (the data is the point, `by=` is a modifier)?

### 2c. In-place / out-of-place pairing

For every function ending in `!` (mutating), check whether a non-mutating counterpart exists with the same base name. For every non-mutating function, check whether an in-place variant would be natural (i.e., the function produces an array-valued result of the same shape/type as an input). Flag asymmetric pairs.

Do not flag `!`-functions where an out-of-place version would not make sense (e.g., `push!` has no natural non-mutating pair in Base either).

### 2d. Boolean and integer flags as positional arguments

Flag functions where a `Bool`, small `Int`, or `Symbol` positional argument is used purely as a configuration switch — something like `f(A, true)` or `f(A, :mode)`. Modern Julia convention is to use keyword arguments for configuration. Positional arguments should represent data, not behavior switches.

Exception: a `Symbol` that selects meaningfully different dispatch (so different that it acts like a different function) may be reasonable; flag it but note the nuance.

### 2e. Reduction `init` argument

For functions that reduce a collection to a scalar (or smaller array) and accept an initial value, check whether that initial value is passed positionally or as an `init` keyword. Modern Julia uses `init`: `reduce(op, A; init=0)`.

### 2f. Sorting and ordering

For functions that sort, rank, or compare elements, check for:
- Custom comparator as positional argument → should be `lt=` keyword
- Key extraction function as positional argument → should be `by=` keyword
- Reverse order as positional `Bool` → should be `rev=` keyword (defaulting to `false`)

### 2g. Output allocation conventions

For functions that return a new array, check:
- Is the output type/eltype hard-coded when it could be inferred from the input via `similar`?
- Is there a way for the caller to provide a pre-allocated output buffer? If not, and the function is likely to be called in a hot loop, flag the absence of an in-place variant (covered by 2c) and note the allocation concern.

### 2h. `do`-block compatibility

Functions whose first argument is a callable should be compatible with `do`-block syntax by putting the callable first. Flag functions where a callable argument exists but is not in the first position, making `do` blocks unusable.

### 2i. Keyword passthrough

Functions that wrap another function (from Base or another package) should generally accept and forward `kwargs...` rather than listing a fixed subset of the underlying function's keywords. Flag functions that explicitly list keywords from an underlying function without forwarding the rest, unless there is a good reason to restrict them.

### 2j. Internal naming consistency

Across the package's own API (not by comparison with Base), look for:
- Analogous operations that are named inconsistently (e.g., one uses `compute_`, another uses `make_`, another uses `build_` for structurally similar operations)
- Functions that differ in argument order for no apparent reason compared to closely related functions in the same package
- Inconsistent keyword argument names across related functions (e.g., `dims` in one function but `dim` in another, or `tol` vs `atol` for tolerance)

---

## Phase 3 — Compile the report

Group findings into three tiers:

**Tier 1 — Breaking changes** (changing the signature would break callers):
List each finding with: function, current signature, proposed signature, rationale by analogy to Base.

**Tier 2 — Non-breaking improvements** (can be introduced while keeping old signature via a compatibility shim or default):
List each finding with the same format.

**Tier 3 — Internal consistency** (naming and ordering issues within the package, no direct Base analogy):
List each finding.

For each tier, note whether there are clusters of related changes (e.g., "all dimension arguments across 5 functions") that should be handled together to avoid a partially-modernized API.

Present the report to the user. **[pause for approval]** Wait for explicit confirmation of which tiers and specific items to address before making any changes.

Once the user confirms their selections:
1. Write the approved change list to `.claude/review-api-approved.md`: one item per line with tier, function name, and what to change.
2. Ask the user to run `/compact` — the source inventory and full review discussion are no longer needed in context.
3. After compacting, read `.claude/review-api-approved.md` to recall the approved items, then proceed to Phase 4.

---

## Phase 4 — Implement approved changes

For each approved change:
1. Update the function signature.
2. If a compatibility shim is appropriate (Tier 2), add a deprecated forwarding method using `Base.@deprecate` or a manual deprecation warning.
3. Update all callers *within the package* (tests, internal uses, examples, docstrings).
4. Run tests via the MCP Julia session to confirm nothing regressed.
5. Commit with a message describing the API change.

Do not batch all changes into one commit — commit each logical group (e.g., "all dimension-argument changes") separately so the history is readable.

---

## Phase 5 — Version bump

If any Tier 1 (breaking) changes were made:
- If the major version is 0, increment the minor version (e.g., 0.3.1 → 0.4.0).
- Otherwise increment the major version.

Update `Project.toml` and commit.

Delete `.claude/review-api-approved.md`.
