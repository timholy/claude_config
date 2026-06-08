# Julia generic indexing

Annotating an argument `AbstractArray` (or `AbstractVector`, etc.) is a
*promise* that the code works for any array — not just `Array`. That includes
arbitrary axes (`OffsetArray`), lazy wrappers (`view`, `PermutedDimsArray`,
`reshape`), GPU arrays, and arrays whose indices aren't `Int`. Either honor
that promise or annotate more narrowly. The cost of breaking it is silent wrong
answers for the very callers the broad annotation invited in.

The axiom that governs indexing is: `a = b[idxs]` implies `a[j] === b[idxs[j]]`.
So `a` inherits its *values* from `b` and its *axes* from `idxs` —
`axes(a) == axes(idxs)`, and `j` ranges over `eachindex(idxs)`. Most rules below
are corollaries: index with something whose axes you want the result to have.
The dual holds for assignment: `a[idxs] = b` sets `a[idxs[j]] = b[j]`.

Honoring it means writing against the data's *indices and axes*, never against
`1:length`:

- Iterate `eachindex(A)`, or `pairs(A)` when you need index-value pairs. Reserve
  `enumerate` for when you genuinely want a 1-based *counter* independent of A's
  keys — not as a stand-in for the index.
- To iterate several arrays together, `for i in eachindex(A, B)`: it both
  validates that they share indices and stays generic. One idiom replaces a
  manual length check plus `1:n`.
- Span one dimension with `axes(A, d)`, not `1:size(A, d)`. Use `firstindex` /
  `lastindex`, not `1` / `length`-as-`end`.
- Allocate index-matched results so axes and array type propagate:
  `similar(y, eltype(y), (axes(y, 1), Base.OneTo(k)))`, not
  `Matrix{T}(undef, length(y), k)`. Use `similar(y, T, ...)` to change eltype.
- Prefer `map` / broadcasting / comprehensions over index-matched inputs when
  you can — they already carry axes through correctly.
- Convert between linear and Cartesian indices with `LinearIndices(A)` /
  `CartesianIndices(A)`, not hand-rolled `(i-1)*n + j` arithmetic.

Check consistency at the top of the function and fail fast:

    axes(A) == axes(B) || throw(DimensionMismatch("A and B must match: $(axes(A)) vs $(axes(B))"))

If you deliberately write 1-based code — sometimes the honest choice — *declare*
it rather than assuming silently:

    Base.require_one_based_indexing(A, B)

An `OffsetArray` caller then gets a clear, immediate error instead of a wrong
result. Declaring the assumption is acceptable; leaving it implicit is not.

This is a correctness property, not a stylistic nicety: it should be enforced by
tests that run the package's entry points on `OffsetArray`- and `view`-wrapped
inputs and assert the results match (and that output axes track input axes).
