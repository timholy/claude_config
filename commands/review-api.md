---
description: Review a Julia package's public API for consistency with modern Julia conventions and idioms
model: Sonnet
effort: medium
---

Review the Julia package in the current working directory for API design convention issues. The goal is not to fix bugs or deprecated syntax — assume the code runs correctly on modern Julia. The goal is to identify places where the package's own API would feel surprising or inconsistent to a user who learned Julia in the modern era (1.6+), by comparison with the conventions established by Base and the standard library.

This skill produces a tiered report, a brief modernization-policy discussion, and an `API_REVIEW_PLAN.md` that decomposes the approved tiered findings into chunks consumed by the companion `/review-implement` skill. This skill does not implement changes — that is `/review-implement`'s job.

The package module name is determined from `Project.toml`.

---

## Phase 1 — Inventory the public API

Invoke the `julia-api-inventory` subagent on the current working directory. It will return a structured inventory of all public method signatures. Work from that inventory — do not re-read the source — to run the convention checks below.

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

### 2k. Overly-restrictive type annotations

Argument types should generally be tight enough to control dispatch. Look for signatures that appear to be inappropriately narrow.

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

Present the report to the user. **[pause for approval]** Wait for explicit confirmation of which tiers and specific items to address before writing the plan. Items the user does not select become `dropped` chunks (recorded with a brief reason) so the plan reflects considered choices, not just acted-upon ones.

Before writing the plan, ask briefly:

- **Modernization policy and breaking-change tolerance**: how aggressive should the modernization be? Is the package pre-1.0 (where breaking changes are cheap) or post-1.0 (where each breaking change is expensive)? Does the user prefer Tier 2 deprecation shims wherever possible, or a clean break? The answer goes into `Stated values`.
- **Release strategy** (only if any approved item is Tier 1 / breaking):
  - Cut a final non-breaking release before the first breaking change?
  - If multiple breaking clusters, release between them or batch into one terminal breaking release?
  Acceptable answers include `decide-later`; the implementer will ask at the relevant moment.

---

## Phase 4 — Write the plan

Convert the approved tiered findings into chunks. Each approved item becomes one
chunk; tightly-related items in the same tier (e.g., "all dimension arguments
across 5 functions") become a **cluster** of chunks sharing a `Cluster` label so
the implementer can warn about half-modernized clusters.

Chunk kind mapping:

- **Tier 1 (breaking)** → `implement`, `Breaking: yes`.
- **Tier 2 (non-breaking)** → `implement`, `Breaking: no`. If the change requires
  a deprecation shim that itself counts as a signature addition, still
  `Breaking: no`.
- **Tier 3 (internal consistency)** → `implement`, `Breaking: no`, usually safe
  to do early.
- **Items the user is unsure about** → `decide`. The implementer will pose the
  question with originating-finding context.
- **Items requiring upstream investigation** (e.g., "audit all call sites") →
  `investigate`.

Write the plan to `API_REVIEW_PLAN.md` in the project root using this schema:

```markdown
# API Review Plan
<!-- Auto-generated by /review-api. Edit freely, but preserve chunk IDs and status values. -->

## Metadata
- **Kind**: `api`
- **Package**: [name]
- **Source review date**: [YYYY-MM-DD]
- **Current version**: [from Project.toml]

## Stated values
[modernization policy and breaking-change tolerance from the Phase 3 close-out]

## Release strategy
- **Pre-breaking-release**: `yes` | `no` | `decide-later` | `n/a (no breaking changes planned)`
- **Inter-cluster releases**: `yes` | `no` | `decide-later` | `n/a`

## Baseline
- Tests pass on the starting commit: `not-yet-checked`
- `Test.detect_ambiguities` count: `not-yet-checked`
- Working tree clean: `not-yet-checked`

## Decisions
<!-- Answers to `decide` chunks land here, with the chunk ID. -->

## Chunks

### CHUNK-001: preflight
- **Kind**: `preflight`
- **Originating finding**: n/a
- **Cluster**: none
- **Breaking**: no
- **Description**: Establish baseline (tests pass, ambiguity count, clean tree).
- **Depends on**: none
- **Verification**: full test suite, `Test.detect_ambiguities`
- **Status**: `not-started`
- **Notes**:

### CHUNK-002: [verb-phrase-name]
- **Kind**: `implement` | `decide` | `investigate`
- **Originating finding**: [tier / convention / function name from the report]
- **Cluster**: [label or "none"]
- **Breaking**: yes | no
- **Description**: [current signature → proposed signature, with rationale by analogy to Base]
- **Depends on**: [CHUNK-XXX, ... or "none"]
- **Verification**: tests for the new signature; deprecation-shim test if Breaking; ambiguity check
- **Status**: `not-started`
- **Notes**:

[... additional chunks ...]

### CHUNK-NNN: version-bump
- **Kind**: `version-bump`
- **Originating finding**: n/a
- **Cluster**: none
- **Breaking**: yes
- **Description**: Bump version per breaking changes (0.x → minor; ≥1.x → major). Update CHANGELOG.
- **Depends on**: [every Breaking: yes chunk, plus any release-breaking chunks]
- **Verification**: full test suite green; no half-finished cluster
- **Status**: `not-started`
- **Notes**:

## Dropped findings
<!-- Items the user chose not to act on, with one-line reasons. Preserved for institutional memory. -->

## Session Log
<!-- The implementer appends an entry after each session. -->

## Open Questions
```

Only include the `version-bump` chunk if at least one chunk is `Breaking: yes`.
If `Release strategy` says `yes` for pre-breaking, also include a
`release-baseline` chunk before the first breaking chunk. If `Inter-cluster
releases` is `yes`, insert `release-breaking` chunks at cluster boundaries.

After writing the file, brief the user:

1. How many chunks the plan contains and the breakdown by tier/kind.
2. The release strategy as recorded.
3. To begin work, run `/review-implement`. The plan is a living document — they
   can edit it freely between sessions.
