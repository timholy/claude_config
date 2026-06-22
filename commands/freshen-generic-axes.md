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

If OffsetArrays is already a project dependency, this step can be skipped.

Mirror however the project already specifies test deps:

- **If `test/Project.toml` exists**: `julia --project=test -e 'using Pkg; Pkg.add("OffsetArrays")'` and add a `[compat]` bound there.
- **If the root `Project.toml` uses `[extras]`/`[targets]`**:
  - **Julia 1.11+**: `julia --project -e 'using Pkg; Pkg.add("OffsetArrays"; target=:extras)'`
  - **Julia 1.10**: `julia --project -e 'using Pkg; Pkg.add("OffsetArrays")'`, then move the entry from `[deps]` to `[extras]` and add `"OffsetArrays"` to the `test` list under `[targets]`.

Add a `[compat]` bound for OffsetArrays — read the installed minor version from the `Pkg.add` output (`OffsetArrays v1.14.0` → `OffsetArrays = "1"`; a loose major bound is fine, the API used here is long-stable). It is test-only, so it never constrains users. Run `Pkg.resolve()` after editing.

## 2. Identify candidate functions

The candidates are exported/public functions whose arguments are arrays (`AbstractArray`/`AbstractVector`/`AbstractMatrix`, or unannotated arguments documented to be arrays) and that either return an array or index into their inputs. Skip functions that take no array, or whose array argument is annotated narrowly enough (`Matrix{Float64}`, `Vector{UInt8}`) that they make no genericity promise.

Classify each candidate by output shape — it determines the assertion in Step 4. Some possible classifications:
- **index-matched array out** (e.g. `map`-like, transforms): result axes must track the input.
- **reduction/scalar out** (e.g. `sum`-like): only value-invariance under wrapping applies; axes don't.
- **multi-array in**: also has a dimension-consistency path to test.

**Genericity is a per-axis promise, not a per-array one.** Before settling on the
output shape, decide what each *dimension* of each array argument means — they do
not all carry the same promise:

- A **data axis** indexes something concrete — samples, features, spatial
  positions, pixels — that exists independently of the operation and flows
  through to the output. Honor the contract here: index it with `axes(A, d)`,
  allocate so its axis propagates, and test that an offset on this dimension
  carries through.
- An **enumeration axis** merely *counts* interchangeable items — mixture
  components, factorization rank, a list of fitted models — with no intrinsic
  key. Its indices are bookkeeping, not data, and 1-based counting is the honest
  representation. Index it with `1:k` / `axes(out, d)` and allocate it as
  `Base.OneTo`; do not try to carry an input axis through it. (For example, in a
  factorization `X ≈ W*H`, the row/column axes of `X` are data axes, but the
  shared component axis `axes(W, 2) == axes(H, 1)` is an enumeration.)

## 3. Static pass over the source

Read the implementations of the candidates. Flag the usual tells from the rule, but reason about each — they are signals, not certainties:
- `1:length(A)`, `1:size(A, d)`, `1:n` derived from a length → usually should be `eachindex`/`axes`.
- `Matrix{T}(undef, …)` / `zeros(T, …)` for an index-matched result → usually should be `similar(A, T, …)`.
- literal `A[1]` should usually be `first(A)` or `A[begin]`
- hand-rolled `(i-1)*n+j` linear arithmetic should subtract `firstindex(A)` instead of 1
- `enumerate` where the loop body uses the counter as an index into `A` (should be `pairs`/`eachindex`); `enumerate` used as a genuine counter is fine.
- missing `axes(A) == axes(B)` (or `eachindex(A, B)`) check in multi-array functions.

Note candidates flagged here — Step 4's tests should confirm them and may catch subtler cases the read missed.

Try to ensure the implementation uses generic operations. Handling offset-axes
with a bunch of `collect`s or `copyto!(OffsetArray(zeros(...)), result)` calls
performs needless allocation and is often strictly worse than just asserting
that the algorithm requires 1-based indexing.

## 4. Scaffold wrap-and-compare tests

For each candidate, run it on the plain input, then on the same data wrapped two ways, and assert the result is consistent. Iterate in the MCP Julia session (with TestEnv + Revise) so recompilation is amortized; this is the pattern, adapt per signature:

```julia
@testset "generic axes: $name" for (name, x) in (("vec", randn(5)), ("mat", randn(4, 3)))
    ref = f(x)

    # shifted axes — the sharpest test
    offset = ntuple(_ -> -2, ndims(x))       # pick sensibly (data axes only, not enumerate axes)
    xo = OffsetArray(x, offset)
    yo = f(xo)
    # The tests below depend on what `f` actually does: here we're assuming that location is irrelevant to the operation it performs.
    # `sqrt.(xo)` and `blur(xo)` would likely qualify — `blur` couples neighbors and may even change shape
    # (if it adds padding), yet stays equivariant either way;
    # `center_of_mass(xo)` does not — its *value* depends on the axes, so it breaks the `collect` line below,
    # not just the `axes` line.
    # Not all `f` behave alike.
    @test collect(yo) == collect(ref)                # the values will be independent of the wrapping
    @test axes(yo) == axes(OffsetArray(ref, offset)) # offsets are preserved even if `f` changes the shape

    # lazy wrapper — catches `Array`-ness / contiguity assumptions
    @test f(view(x, ntuple(_ -> Colon(), ndims(x))...)) == ref
end
```

For a function that *legitimately* does not promise generic axes on *any* dimension, the correct outcome is not a fix but a declaration: it should call `Base.require_one_based_indexing` on its inputs, and the test asserts an offset input errors cleanly (`@test_throws f(OffsetArray(...))`). That is a passing, intentional test — not a gap. `require_one_based_indexing` is whole-array, so it is the right call only when every axis of the argument is an enumeration (or the algorithm really wants to be 1-based).

## 5. Report and propose fixes

Summarize for the user: which candidates pass, which fail (with the offending source line and whether it's a wrong value or wrong axes), and which should instead declare `require_one_based_indexing`. Propose the fixes — typically `eachindex`/`axes`/`similar` substitutions per the rule.

**Wait for user approval before changing any source.**

## 6. Implement and verify

Apply the approved fixes. Add the tests in a `@testset "generic axes"` block (sibling to any existing quality-checks testset, e.g. Aqua/ExplicitImports). Then run the full suite — on the current release, and on the lowest supported Julia if the package supports it — and confirm green. Do not finish with a red suite: a failure here means either a fix is incomplete or a function should have declared `require_one_based_indexing` (back to Step 4/5).
