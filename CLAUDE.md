# Debugging Julia code

- Exploit `Revise` to amortize the cost of compilation time, which for Julia is
  quite high. This *requires* that you use the MCP server to avoid starting a
  new Julia session each time.

- Run package test suites in an interactive session like this:
  `julia --project 'using Revise, TestEnv; TestEnv.activate(); include("test/runtests.jl")'`

- Use `Pkg.test()` for a final run only when ready to submit a pull request.

# Packages

- Do not bias decisions about packages based on what is already installed. Use
  Julia's package manager to add any needed dependencies.

- Use the local `Project.toml` environment when available. Revise, TestEnv,
  Cthulhu, and some other developer-oriented tools are in my global (fallback)
  environment.

- When adding new pacakges to a local project, also update the `[compat]`
  section of `Project.toml` to bound the version of the new dependency. Where
  possible, choose lower bounds compatible with the LTS release of Julia
  (currently 1.10).

- As needed, find the source for session-loaded packages with
  `Pkg.pkgdir(M::Module)`. For packages not loaded into the session, before
  searching the hard drive check the currently-active project's `Manifest.toml`
  for the path.

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
  Exception: packages that still support Julia versions before 1.6 need to
  write it the long way.

- any new `convert(::Type{T}, x)` methods should always return an object of the
  requested type `T`. You should mentally model this as
  `convert(::Type{T}, x)::T`. If the caller writes `convert(Vector{Real}, list)`,
  the return type should be `Vector{Real}` and not `Vector{T}` for some concrete
  `T<:Real`. The same goes for type-constructors.
