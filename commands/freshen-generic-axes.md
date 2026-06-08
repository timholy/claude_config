---
description: Audit a Julia package's array functions for 1-based indexing assumptions, add OffsetArrays/view tests that enforce the generic-indexing contract, and report fixes
model: Sonnet
effort: low
---

The contract being enforced is in `rules/julia-generic-indexing.md`: a function
taking `AbstractArray` promises to work for any array, and `a = b[idxs]` implies
`a[j] === b[idxs[j]]`, so results inherit values from the data and axes from the
index. This skill turns that promise into tests that fail loudly when broken —
the durable teacher, since a red suite corrects code that a style rule does not.

## 1. Add OffsetArrays as a test dependency

Mirror however the project already specifies test deps:

- **If `test/Project.toml` exists**: `julia --project=test -e 'using Pkg; Pkg.add("OffsetArrays")'` and add a `[compat]` bound there.
- **If the root `Project.toml` uses `[extras]`/`[targets]`**:
  - **Julia 1.11+**: `julia --project -e 'using Pkg; Pkg.add("OffsetArrays"; target=:extras)'`
  - **Julia 1.10**: `julia --project -e 'using Pkg; Pkg.add("OffsetArrays")'`, then move the entry from `[deps]` to `[extras]` and add `"OffsetArrays"` to the `test` list under `[targets]`.

Add a `[compat]` bound for OffsetArrays — read the installed minor version from the `Pkg.add` output (`OffsetArrays v1.14.0` → `OffsetArrays = "1"`; a loose major bound is fine, the API used here is long-stable). It is test-only, so it never constrains users. Run `Pkg.resolve()` after editing.

## 2. Identify candidate functions

The candidates are exported/public functions whose arguments are arrays (`AbstractArray`/`AbstractVector`/`AbstractMatrix`, or unannotated arguments documented to be arrays) and that either return an array or index into their inputs. Skip functions that take no array, or whose array argument is annotated narrowly enough (`Matrix{Float64}`, `Vector{UInt8}`) that they make no genericity promise.

Classify each candidate by output shape — it determines the assertion in Step 4:
- **index-matched array out** (e.g. `map`-like, transforms): result axes must track the input.
- **reduction/scalar out** (e.g. `sum`-like): only value-invariance under wrapping applies; axes don't.
- **multi-array in**: also has a dimension-consistency path to test.

## 3. Static pass over the source

Read the implementations of the candidates. Flag the usual tells from the rule, but reason about each — they are signals, not certainties:
- `1:length(A)`, `1:size(A, d)`, `1:n` derived from a length → usually should be `eachindex`/`axes`.
- `Matrix{T}(undef, …)` / `zeros(T, …)` for an index-matched result → usually should be `similar(A, T, …)`.
- literal `A[1]` / `A[end]`-as-length, hand-rolled `(i-1)*n+j` linear arithmetic.
- `enumerate` where the loop body uses the counter as an index into `A` (should be `pairs`/`eachindex`); `enumerate` used as a genuine counter is fine.
- missing `axes(A) == axes(B)` (or `eachindex(A, B)`) check in multi-array functions.

Note candidates flagged here — Step 4's tests should confirm them and may catch subtler cases the read missed.

## 4. Scaffold wrap-and-compare tests

For each candidate, run it on the plain input, then on the same data wrapped two ways, and assert the result is consistent. Iterate in the MCP Julia session (with TestEnv + Revise) so recompilation is amortized; this is the pattern, adapt per signature:

```julia
@testset "generic axes: $name" for (name, x) in (("vec", randn(5)), ("mat", randn(4, 3)))
    ref = f(x)

    # shifted axes — the sharpest test
    xo = OffsetArray(x, ntuple(_ -> -2, ndims(x)))
    yo = f(xo)
    @test collect(yo) == collect(ref)        # values invariant to the wrapping
    @test axes(yo) == axes(xo)               # index-matched output only; drop for reductions

    # lazy wrapper — catches `Array`-ness / contiguity assumptions
    @test f(view(x, ntuple(_ -> Colon(), ndims(x))...)) == ref
end
```

`axes(yo) == axes(xo)` is the load-bearing line for index-matched outputs — it is exactly what `1:length`/`Matrix{T}(undef,…)` code cannot satisfy. For reductions, keep only the value comparison. For multi-array functions, also assert the mismatch path: `@test_throws DimensionMismatch f(randn(5), randn(6))`.

For a function that *legitimately* does not promise generic axes, the correct outcome is not a fix but a declaration: it should call `Base.require_one_based_indexing` on its inputs, and the test asserts an offset input errors cleanly (`@test_throws f(OffsetArray(...))`). That is a passing, intentional test — not a gap.

## 5. Report and propose fixes

Summarize for the user: which candidates pass, which fail (with the offending source line and whether it's a wrong value or wrong axes), and which should instead declare `require_one_based_indexing`. Propose the fixes — typically `eachindex`/`axes`/`similar` substitutions per the rule.

**Wait for user approval before changing any source.**

## 6. Implement and verify

Apply the approved fixes. Add the tests in a `@testset "generic axes"` block (sibling to any existing quality-checks testset, e.g. Aqua/ExplicitImports). Then run the full suite — on the current release, and on the lowest supported Julia if the package supports it — and confirm green. Do not finish with a red suite: a failure here means either a fix is incomplete or a function should have declared `require_one_based_indexing` (back to Step 4/5).
