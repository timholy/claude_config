# Debugging Julia code

- Exploit `Revise` to amortize the cost of compilation time, which for Julia is
  quite high. This *requires* that you use the MCP server to avoid starting a
  new Julia session each time.

- Use `Pkg.test()` for a final run only when ready to submit a pull request.

# GUI packages

For packages that require a display (e.g., Gtk, Qt, Makie), avoid repeated
`xvfb-run julia ...` invocations. Instead:

1. Start a virtual display once in the background:
   `Xvfb :99 -screen 0 1024x768x24 &`
2. Set `ENV["DISPLAY"] = ":99"` in the MCP Julia session before loading the
   package, so Revise-based iteration still works.

Fall back to `xvfb-run julia ...` via Bash only for final `Pkg.test()` runs or
when the MCP session cannot be reconfigured.

# Packages

- Use the local `Project.toml` environment when available. Revise, TestEnv,
  Cthulhu, and some other developer-oriented tools are in my global (fallback)
  environment.

- Do not bias decisions about packages based on what is already installed.

- When adding new pacakges to a local project, also update the `[compat]`
  section of `Project.toml` to bound the version of the new dependency. Where
  possible, choose lower bounds compatible with the LTS release of Julia
  (currently 1.10).

- As needed, find the source for session-loaded packages with
  `Pkg.pkgdir(M::Module)`. For packages not loaded into the session, before
  searching the hard drive check the currently-active project's `Manifest.toml`
  for the path.

# Style guide

- avoid being unnecessarily restrictive about method arguments. `f(A::Matrix{Float64})`
  silently excludes sparse matrices, GPU arrays, `Float32`, dual numbers, and anything
  else that would work fine — the caller gets a confusing `MethodError` instead.
  Annotate only as specifically as the implementation requires: use `Matrix{Float64}`
  only when a `ccall` or similar demands a specific memory layout and element type;
  use `AbstractMatrix` when 2-D structure matters; use `AbstractArray` when it does
  not; leave unannotated when the method works for any input. Annotate to control
  dispatch and resolve ambiguities, not to document intent.

- avoid redundant keyword syntax: when a variable name matches the keyword argument
  name, use the short form `f(; max_iter)` instead of `f(; max_iter=max_iter)`.
  This applies at function call sites, `NamedTuple` construction, and similar contexts.
  Exception: packages supporting Julia before 1.6 must use the long form.

- any new `convert(::Type{T}, x)` methods should always return an object of the
  requested type `T`. You should mentally model this as
  `convert(::Type{T}, x)::T`. If the caller writes `convert(Vector{Real}, list)`,
  the return type should be `Vector{Real}` and not `Vector{T}` for some concrete
  `T<:Real`. The same goes for type-constructors.

# Analysis-project conventions

Projects driven by `/new-analysis-plan` and `/new-analysis-implement` use two
stable paths:

- `artifacts/CHUNK-XXX/` — human-readable per-chunk outputs (plots, tables,
  summary stats). Predictable; safe to point users at.
- `scripts/explore_chunk_XXX.{jl,py,R,m}` — Revise-friendly playground that
  generates the chunk's artifact and serves as the entry point for interactive
  poking. For Julia, these scripts use `using Revise; using <Package>` so the
  MCP session stays warm.
