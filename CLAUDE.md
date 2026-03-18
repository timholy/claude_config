# Debugging Julia code

This assumes usage of the MCP server. Tips:
- Exploit `Revise` to amortize the cost of compilation time, which for Julia is quite high

- Generally it's best to run a package test suite in an interactive session (to
  leverage Revise), saving `Pkg.test()` for a final run only when ready to
  submit a pull request. Many packages require `TestEnv` to run their tests in
  an interactive session.

# Packages

- Use the local Project.toml environment when available. I have some tools in my
  global (fallback) environment.
- find the source for session-loaded packages with `Pkg.pkgdir(M::Module)`
- for non-loaded packages, before browsing the global environment or the user's
  depot, first check the currently-active project's `Manifest.toml`
- for tasks that can be solved by packages not in the project's environment,
  before writing custom code ask the user if the relevant package(s) should be
  added to the project.
  + Example: the CSV file format is often simple, but there are some gotchas.
    It's typically safer to use CSV.jl.
  + When considering adding a package and the target project is ambiguous, ask
    the user for clarification. Example: "I need to parse a CSV file. Should I
    1. Make CSV.jl a project dependency? 2. Make CSV.jl a test dependency? 3.
    Add CSV.jl transiently? 4. Write my own parser?"
- when adding packages to a project, don't insert the SHA from your own
  knowledge: use Julia's package manager. Also update the `[compat]` section of
  `Project.toml` to bound the version of the new dependency. Where possible,
  choose lower bounds compatible with the LTS release of Julia (currently 1.10).

# Style guide

- avoid being unnecessarily restrictive about method arguments: for example,
  `f(A::Matrix{Float64})` is usually too specific unless you have clear reasons
  (e.g., if `f` will `ccall` code that expects a particular memory layout).
  `f(A::AbstractMatrix)` is typically a better choice. Foremost, signatures
  should be specific enough to control dispatch and resolve ambiguities.
  Judicious annotation can also make code easier to read.

- avoid redundant keyword syntax: if `f` accepts a kwarg called `max_iter`
  and you already have an in-scope variable `max_iter`, then calling it as
  `f(; max_iter)` suffices; don't write this as `f(; max_iter=max_iter)`.
  Exception: packages that still support Julia 1.0 need to write it the long way.

- any new `convert(::Type{T}, x)` methods should always return an object of the
  requested type `T`. You should mentally model this as
  `convert(::Type{T}, x)::T`. If the caller writes `convert(Vector{Real}, list)`,
  the return type should be `Vector{Real}` and not `Vector{T}` for some concrete
  `T<:Real`. The same goes for type-constructors.
