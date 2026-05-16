---
description: Review a Julia package for dependency-interface compliance, latent bugs, and user friction by reading source, tests, and docs directly
model: Opus
effort: high
---

Review the Julia package in the current working directory for issues that the structured `/review-design` and `/review-api` skills are designed *not* to surface. Those skills work from distilled artifacts (a conceptual map, an API inventory) and explicitly assume the code is correct and idiomatic. This skill is the deliberate inverse: read source, tests, and documentation **directly**, and look for things that only become visible inside the implementation and at the package's seams with the outside world.

Three focus areas:

1. **Dependency-interface compliance** — for each declared dependency, is the package using that dependency's *public* API correctly and idiomatically? Does the package implement the interfaces it claims to support (Tables, AbstractTrees, AbstractArrays, Iterator protocol, etc.) completely and consistently?
2. **Latent bugs and suspicious code** — paths that look wrong, error handling that masks failures, off-by-ones, type instabilities that change semantics (not just performance), tests that pass for the wrong reason.
3. **User friction** — the kind of paper cuts that don't violate any convention but make the package annoying to use: bad error messages, missing convenience constructors, common tasks that take N steps when they should take one, undocumented preconditions, examples that don't run.

This skill produces a tiered report and an `INTEGRATION_REVIEW_PLAN.md` that decomposes the agreed-upon findings into chunks consumed by the companion `/review-implement` skill. Do not implement any changes in this skill — that is `/review-implement`'s job.

The package module name is determined from `Project.toml`.

---

## Phase 0 — Size preflight

This skill reads source/tests/docs into the main context (unlike `/review-design` and `/review-api`, which delegate the bulk read to a distillation subagent). Cost therefore scales with package size, and depth of analysis degrades when the model is asked to read too much in one pass.

Measure the total character count across `src/`, `ext/`, `test/`, `docs/src/`, `README.md`, and any `examples/` directory:

```bash
find src ext test docs/src examples -type f \( -name '*.jl' -o -name '*.md' \) 2>/dev/null | xargs wc -c 2>/dev/null | tail -1
# plus README.md
```

Apply the **attention ceiling** (window-independent — reflects how much source the model can read carefully in one pass, not how much fits):

- **Under ~250K chars total**: proceed to Phase 1 as written.
- **~250K–500K chars**: surface the size to the user and offer a strategy menu before proceeding:
  - (a) Restrict scope to one or two of 2a–2f (which areas matter most to you?).
  - (b) Restrict scope to a subdirectory of `src/` (e.g., one major submodule).
  - (c) Use an `Explore`-style subagent for targeted queries per check (loses the "one careful reading pass" benefit but preserves coverage).
  - (d) Proceed anyway with the understanding that depth will suffer — acceptable for a first-pass scan, not for a thorough review.
- **Above ~500K chars**: refuse the default mode. Require the user to pick (a), (b), or (c). Do not pretend to do the full review.

There is also a **context-fit ceiling** that depends on the user's window size, which this skill cannot query at runtime. With a default ~200K-token window, ~600K characters of source is the practical hard limit; with a 1M-token window, that scales up roughly 5×. If the user has a larger window than default and wants to push past the attention-ceiling thresholds above, that is their judgment call — but the attention ceiling still applies, so depth will suffer regardless.

Record the measurement and the chosen strategy in one line at the top of the eventual report (e.g., "Phase 0: 312K chars total; user chose strategy (a), focusing on 2a and 2c").

---

## Phase 1 — Read directly

Do **not** invoke `pkg-conceptual-mapper` or `julia-api-inventory` — they would defeat the purpose. Instead, read directly:

1. `Project.toml` — note every `[deps]` entry and its declared `[compat]` bound. These are the dependencies whose interfaces the package consumes.
2. All files in `src/`. Read implementations, not just signatures. Note `using`/`import` statements per file — which dependency-provided symbols are actually used where.
3. `test/` — the test suite is documentation of intended behavior and a good place to spot tests that pass for the wrong reason.
4. `README.md`, `docs/src/`, and any `examples/` — the user-facing surface. Examples that no longer run, or that demonstrate awkward idioms, are friction.

For large packages, prioritize: files most central to the package's purpose first, then peripheral utilities. If a file is clearly machine-generated or vendored, note it and move on.

---

## Phase 2 — Checks by focus area

### 2a. Dependency-interface compliance

**Out of scope — delegated to deterministic tooling**, do not duplicate:
- "Does the package import non-public symbols from a dependency?" → ExplicitImports.jl (`/freshen-explicit-imports`) catches this reliably across `using`/`import` and qualified-access forms.
- "Are there declared dependencies no longer used in source?" → Aqua.jl's `test_stale_deps` (`/freshen-aqua`) catches this.

If the user has not yet run those skills on this package, mention it in the report's preamble and recommend running them — but do not attempt the same analysis by hand in this skill. Doing so produces noisier, less reliable findings than the tools, and wastes the reading-pass budget on a problem that is already solved.

**In scope — qualitative dep-usage questions tooling cannot answer.** For each `[deps]` entry, identify what *kind* of dependency it is and apply the relevant checks:

- **Interface packages** (Tables, AbstractTrees, ArrayInterface, SciMLBase, MLJModelInterface, CommonSolve, StatsAPI, etc.): does the package implement the *full* interface required for its types to function with the broader ecosystem? E.g., a "Tables-compatible" type that defines `Tables.istable` and `Tables.rows` but not `Tables.schema` will silently fail in some downstream consumers. Look up the actual interface contract — do not guess.
- **Generic programming via interfaces and traits, vs representation-dependent code.** This is the most valuable check in 2a and the one most worth thinking carefully about. Look for places where the package writes hand-rolled methods that depend on a concrete representation when a generic interface would do. Symptoms:
  - `for i in 1:length(v); v[i]; ...` instead of `for x in v` or `for i in eachindex(v)`. The explicit-index form silently breaks for `OffsetArrays`, sparse iteration, generators, etc.
  - `if A isa Matrix ... else ... end` branches that could be handled by dispatching on `AbstractMatrix` or a trait (`IndexStyle`, `ArrayInterface.parent_type`).
  - Direct field access (`x.foo`) on a type owned by another package, when an accessor function exists. Field layouts are not API.
  - Methods specialized on `Vector{T}` / `Matrix{T}` / `Array` when the operation works for any `AbstractArray` and would benefit from being callable with views, GPU arrays, sparse arrays, dual numbers, etc. (See the user's CLAUDE.md guidance on argument annotations — overly-restrictive types silently exclude valid inputs.)
  - Hand-coded property dispatch (`Symbol`-keyed `if`/`elseif`) where multiple dispatch on a wrapper type would be more idiomatic.
- **Numerical/algorithmic packages** (LinearAlgebra, SparseArrays, Statistics, FFTW): is the package using the right entry point? Hand-rolled loops where a Base/stdlib function would do are often less stable as well as slower. Conversely: is the package using a high-level entry point when a lower-level one would compose better with the caller's chosen factorization or storage format?
- **Container/iterator packages** (DataStructures, OrderedCollections, IterTools): is the package using public constructors and accessors? (Internal-field access is caught by ExplicitImports for qualified accesses, but unqualified field-access on a value of a dep type — e.g., `x.internal_field` after `x = SomeDep.Foo()` — is not always caught and is worth a manual check.)
- **Logging, Printf, Dates, Random**: standard pitfalls — `println` in library code (instead of `@info`/`@debug` or writing to a passed `IO`), `rand()` without a passed RNG (breaks reproducibility for callers), `now()` instead of `Dates.now(UTC)` for stored timestamps, etc.

Also check `[compat]` bounds: is the lower bound of a dependency so old that the package is forced to avoid newer, better APIs? (The inverse — *too tight* upper bounds — is a separate maintenance question, not an integration concern.)

### 2b. Implementations of standard Julia interfaces

Independent of declared dependencies, check the package's own types against the implicit interfaces of Base:

- Iterator protocol: if `iterate` is defined, are `length`/`size` defined when knowable, and `IteratorSize` / `IteratorEltype` traits set when the defaults are wrong?
- Indexing: if `getindex` is defined, are `firstindex`/`lastindex` defined? Does `axes` return something sensible for `eachindex` to consume?
- AbstractArray subtypes: `size`, `getindex`, `setindex!` (if mutable), `IndexStyle` — and do operations like `similar`, `copy`, broadcasting actually work, or do they fall through to a wrong default?
- `==` defined without matching `hash` (Base's `==` / `hash` contract — review-design checks this from the map; here, look for it inside `src/`).
- `show` methods: does `show(io, ::MIME"text/plain", x)` exist for types a user will actually see in the REPL? Does `show(io, x)` produce something parseable or at least round-trippable?
- `convert` and constructor methods that return the wrong type: as long as `T` is concrete, the contract should almost always be `convert(::Type{T}, x)::T` (i.e., it should return a `T`). Example: `convert(Vector{Real}, list)` should never return a `Vector{Int}` even if `list` contains nothing but `Int`s. However, `convert(Real, x)` can return an `Int` since all instances must have concrete type and `Real` is not concrete.

### 2c. Latent bugs and suspicious code

Read with a skeptical eye. Things to flag:

- Bare `catch` clauses that swallow exceptions, or `catch e` blocks that log-and-continue when the operation cannot meaningfully proceed.
- `try` blocks with no `finally` around a resource (file handle, lock) that needs deterministic cleanup.
- Floating-point comparisons with `==` where `≈` / `isapprox` is intended.
- Off-by-one risks at boundaries (`1:length(x)` where `eachindex(x)` would be safer; `for i in 1:n-1` patterns).
- Type-unstable code where the instability changes *semantics*, not just performance — e.g., a function that sometimes returns `Int` and sometimes `Vector{Int}` depending on input.
- Mutation of a shared default argument value (`function f(x, buf=Float64[])` — every caller shares the same buffer).
- Tests that assert nothing meaningful: `@test foo(x) !== nothing`, `@test_nowarn` around a function that never warns anyway, tests that would pass even if the implementation were `return input`.
- `@assert` used for input validation (gets compiled out under `--check-bounds=no` in some settings — `throw(ArgumentError(...))` is the right tool).
- `eval` / `@eval` at runtime in performance-sensitive paths.
- World-age hazards: `@eval` followed by an immediate call within the same function.

For each, name the file and line, quote the relevant snippet, and explain the failure mode. Distinguish "definitely a bug" from "smells like a bug, worth a closer look."

### 2d. User friction

Read the README and examples as if you have never seen this package before. For each common task the package supports, count the steps. Flag:

- Common tasks that require boilerplate the package could absorb (e.g., always wrapping the input in a particular constructor).
- Constructors that demand all-keyword arguments when there is one obvious primary input.
- Error messages that say what failed but not what the user should do (`ArgumentError("invalid")` with no context).
- Functions whose docstring describes *what it does* but not *what it returns* or *when to use it vs. a sibling*.
- Examples in the README or docs that no longer run (because the API moved). Try to mentally execute them; if uncertain, note them for verification.
- Functions whose argument names in the signature do not match the names used in the docstring.
- Required-but-undocumented preconditions (`f(x)` works only when `issorted(x)`, but the docstring does not say so).
- Defaults that are wrong for the common case (forcing every caller to override).
- Missing `Base.show` for a type the user will see, leading to unhelpful `Foo(0x00007f...)` output.

### 2e. Test and doc smells

- Tests that are skipped, broken, or commented out without explanation.
- `@test_broken` blocks older than a year that nobody has revisited.
- Doctests that have drifted from the implementation (output blocks that no longer match).
- Missing tests for any code path that handles errors — error paths are notoriously where the bugs live.
- Documentation pages that reference removed or renamed functions.

### 2f. Context-dependent checks

These two domains produce confident-sounding false positives when applied speculatively, so they run only when a clear trigger is present in Phase 1. **Decide first whether each trigger is met; if not, write a single line in the report (e.g., "thread-safety: not applicable — no threading primitives") and skip. Do not look for these patterns speculatively.**

#### Thread-safety hazards

Trigger: the package uses any of `Threads.@threads`, `Threads.@spawn`, `@async`, `Channel`, `Atomic`/`@atomic`, `ReentrantLock`/`SpinLock`, or explicitly claims thread-safety in its README or docstrings; **or** it is the kind of library plausibly called from user-threaded code (e.g., a numerical primitive, a parser invoked per-row, a logger). Utility libraries with no concurrency story do not qualify.

If triggered, look for *obvious* hazards only:
- Shared mutable state (a module-level `Dict`, `Vector`, or `Ref`) written without a lock, when reads or writes can happen from multiple tasks.
- `Threads.@threads` or `@spawn` over a loop that mutates a non-thread-local accumulator.
- Lazy initialization (`isnothing(cache) && (cache = ...)`) without synchronization.
- `Channel` used without `close` on the producer side, leaving consumers blocked.
- Use of `task_local_storage` where caller assumptions about task identity may be violated.

For each finding, name the file:line and the specific concurrency primitive in use. Do not flag patterns as "potentially racy" without a concrete interleaving you can describe in one sentence.

#### Numerical-stability red flags

Trigger: the package's stated purpose involves nontrivial numerical computation — linear algebra, statistics, ODE/PDE solvers, optimization, signal processing, geometry with floating-point coordinates, probabilistic methods. Parsers, IO, data structures, web tooling, and CLI utilities do not qualify.

If triggered, look for specific patterns only:
- Naive single-pass variance / standard deviation: `sum(x.^2)/n - (sum(x)/n)^2` (or equivalent `E[X²] - E[X]²` accumulators), which suffers catastrophic cancellation when the variance is small relative to the mean squared. The two-pass form `sum((x .- mean(x)).^2) / (n-1)` is fine; Welford's algorithm or `Statistics.var` is fine. Flag the single-pass form, not the two-pass form.
- Catastrophic cancellation patterns: `1 - cos(x)` near zero (use `2*sin(x/2)^2`); `sqrt(1+x) - 1` near zero (use `expm1(log1p(x)/2)` or similar); `log(1+x)` for tiny `x` instead of `log1p(x)`; `exp(x) - 1` instead of `expm1(x)`.
- Hand-rolled matrix operations where a `LinearAlgebra` call would be more stable (e.g., normal-equations `(A'A) \ (A'b)` instead of `A \ b`).
- Floating-point accumulation in long loops without compensated summation, when the package's accuracy claims would warrant it.
- Comparison or division near zero without a tolerance or guard.

For each finding, name the file:line, the specific pattern, and the standard idiom that addresses it. Do not flag generic "could lose precision" concerns without a concrete input where the loss would matter.

---

## Phase 3 — Report

Group findings into three tiers:

**Tier 1 — Bugs and correctness issues**: Things that are wrong or very likely wrong. Subdivide into "definite" and "suspicious." Include file:line for each.

**Tier 2 — Dependency / interface compliance gaps**: Incomplete interface implementations, use of dependency internals, missing standard Base methods. These are usually non-breaking *fixes* (adding methods) but can be load-bearing for downstream users.

**Tier 3 — User friction**: Paper cuts. Often not obviously broken, but each one represents avoidable annoyance.

For each finding: file and line, what you observed, why it matters, and a suggested change (or, for ambiguous cases, the question to ask the author).

Note clusters of related findings (e.g., "all four `iterate` types are missing `IteratorSize`") so they can be addressed together.

Present the report. **[pause for approval]** Wait for explicit confirmation of which tiers and which specific items to address before writing the plan. Items the user does not select become `dropped` chunks (each with a one-line reason in `Notes`).

Before writing the plan, ask the user for a short paragraph (or bullets) covering:

- **Risk tolerance for behavior changes** — for ambiguous bugs, prefer to preserve current behavior (with a deprecation/warning) or fix outright?
- **Scope of dependency-interface work** — willing to take on full interface implementations, or only fix the obviously broken bits?
- **Friction threshold** — fix all friction items, or only those that affect the documented common path?

The reply lands verbatim in the plan's `Stated values` section.

Also ask: **"Would you like to post this review to a GitHub issue? If so, provide the issue number."** If the user provides one, record it in the plan's Metadata as `- **Issue**: #NNN`; otherwise record `- **Issue**: n/a`. Commit messages written by the implementer should reference the issue number when one is set.

Also, only if any approved item is likely to be breaking (most bug fixes that change observable behavior count), ask about release strategy: cut a final non-breaking release before the first behavior change? Release between clusters or batch into one terminal release? `decide-later` is acceptable.

---

## Phase 4 — Write the plan

Convert the approved findings into chunks. The default is one chunk per finding, but **merge before splitting** when findings are small and conceptually unified — same file, same dependency interface, or one coherent fix. Aim for chunks worth a CI cycle and a focused review.

Items that remain unmerged but are tightly related become a **cluster** (e.g., "tables-interface-completion", "error-message-pass") so the implementer can warn about half-finished clusters.

Chunk kind mapping:

- **Tier 1 definite bugs** → `implement`. Mark `Breaking: yes` only if the fix changes documented behavior that callers may depend on; many bug fixes are non-breaking.
- **Tier 1 suspicious / needs verification** → `investigate` first, then a follow-up `implement` chunk added by the investigator if confirmed.
- **Tier 2 interface gaps** → `implement`, usually `Breaking: no` (adding methods is additive).
- **Tier 2 use of dependency internals** → `implement`, with a note flagging the public alternative; or `investigate` if no clear public alternative exists.
- **Tier 3 friction** → `implement`, `Breaking: no` for additive fixes (better error messages, additional constructors); `Breaking: yes` only if the friction-fix changes a default value or signature.
- **Items the user is unsure about** → `decide`.

Write the plan to `INTEGRATION_REVIEW_PLAN.md` in the project root using this schema. The chunk schema is intentionally slim: only `Kind`, `Description`, `Status`, and `Notes` are required. Add `Breaking: yes`, `Depends on: ...`, or `Cluster: ...` only when non-default. Reference the originating finding inline (file:line and a phrase, not a separate field).

```markdown
# Integration Review Plan
<!-- Auto-generated by /review-integration. Edit freely, but preserve chunk IDs and status values. -->

## Metadata
- **Kind**: `integration`
- **Package**: [name]
- **Source review date**: [YYYY-MM-DD]
- **Current version**: [from Project.toml]
- **Issue**: #NNN | n/a

## Stated values
[paragraph or bullets from the close-of-report]

## Release strategy
- **Pre-breaking-release**: `yes` | `no` | `decide-later` | `n/a (no breaking changes planned)`
- **Inter-cluster releases**: `yes` | `no` | `decide-later` | `n/a`

## Decisions
<!-- Answers to `decide` chunks land here, with the chunk ID. -->

## Chunks

### CHUNK-001: preflight
- **Kind**: `preflight`
- **Description**: Establish baseline — tests pass, `Test.detect_ambiguities` count, clean tree, current version. Record results in this chunk's Notes.
- **Status**: `not-started`
- **Notes**:

### CHUNK-002: [verb-phrase-name]
- **Kind**: `implement` | `decide` | `investigate`
- **Description**: [file:line — what the chunk fixes/answers; reference the originating tier and finding inline]
- **Status**: `not-started`
- **Notes**:

# Add only when non-default:
# - **Breaking**: yes
# - **Depends on**: CHUNK-XXX, ...
# - **Cluster**: [label]

[... additional chunks ...]

## Session ledger
<!-- The implementer appends one line after each session: `- YYYY-MM-DD CHUNK-XXX (name) → next: CHUNK-YYY` -->

## Open Questions
```

If any chunks are `Breaking: yes`, append a terminal `version-bump` chunk depending on every breaking chunk (and on any `release-breaking` chunks if `Inter-cluster releases` is `yes`).

After writing the file, brief the user:

1. How many chunks the plan contains and the breakdown by tier/kind.
2. The release strategy as recorded.
3. To begin work, run `/review-implement`. The plan is a living document — they can edit it freely between sessions.

---

## Composing with the other review skills

If `DESIGN_REVIEW_PLAN.md` or `API_REVIEW_PLAN.md` already exists, briefly note this to the user before starting Phase 2: findings that overlap with chunks already in those plans should be cross-referenced rather than re-listed. The goal is one chunk per problem across the three plans, not three chunks for the same problem.
