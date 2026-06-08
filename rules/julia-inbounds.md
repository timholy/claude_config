# Julia @inbounds

The default is **no `@inbounds`**. Its downside is not a wrong-but-visible
answer — it is silent undefined behavior: an out-of-range access under
`@inbounds` reads or writes arbitrary memory instead of throwing a
`BoundsError`. That is the sharpest possible violation of fail-fast, so the
annotation has to earn its place rather than be added by reflex.

Most of the time you don't need it. Iterating `eachindex(A)` (see
[[julia-generic-indexing]]) already lets the compiler prove the accesses are
in-bounds and elide the checks itself — you get the speed without the unsafety.
The same `eachindex`/`axes` habit that makes code generic also makes
bounds-check elision automatic. Reach for the annotation only when that hasn't
happened.

`@inbounds` is *not* a "make it faster" button:

- It can make code **slower**. The bounds check it removes is often already
  free or already elided, and `@inbounds` can block LLVM transformations
  (vectorization among them) that would otherwise fire.
- It can make code **wrong** — silently, per the above.

So add it only when *all* of these hold, and prefer to leave it out when in
doubt:

- profiling shows the bounds check is a real bottleneck;
- the compiler genuinely cannot prove safety on its own (i.e. `eachindex`-style
  iteration did not already elide it);
- the in-bounds property is locally provable *and* covered by a test.

When it is warranted:

- wrap the **minimal** expression, never a whole function body;
- never apply it to an index derived from arithmetic or user input without a
  preceding guard;
- for a custom `getindex`, express the contract with `@boundscheck` and
  `Base.@propagate_inbounds` rather than scattering `@inbounds` at call sites.

A new `@inbounds` appearing in a diff is exactly the kind of unjustified
complexity a code review should flag and ask to see a benchmark for; that
scrutiny lives in review, not in a separate stage.

(CI may optionally run the test suite with `--check-bounds=yes` to neutralize
every `@inbounds` and turn any out-of-range access into a caught `BoundsError`.
Don't force this locally — the forced recompilation cost is substantial.)
