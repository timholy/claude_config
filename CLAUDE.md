# Text

- use American spellings

# Stance

- like most scientists, I strongly favor "fail-fast" over "silently try to
  continue." I want to know when unexpected things happen so that I can inspect
  them and understand the underlying causes.

# Julia versions

- `julia` uses the LTS (1.10)
- `julia +1` uses the current release (currently 1.12)

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

# Julia packages

- Use the local `Project.toml` environment when available. Revise, TestEnv,
  Cthulhu, and some other developer-oriented tools are in my global (fallback)
  environment.

- Do not bias decisions about packages based on what is already installed.

- When adding new pacakges to a local project, also update the `[compat]`
  section of `Project.toml` to bound the version of the new dependency. Where
  possible, choose lower bounds compatible with the LTS release of Julia
  (currently 1.10). After making edits to `Project.toml`, run `Pkg.resolve()`.
  Resolver errors sometimes indicate package conflict; they can also occur upon
  downgrading the Julia version. `Pkg.update()` can fix such errors. Julia
  supports having multiple `Manifest-vX.Y.toml` files for different Julia
  versions.

- As needed, find the source for session-loaded packages with
  `Pkg.pkgdir(M::Module)`. For packages not loaded into the session, before
  searching the hard drive check the currently-active project's `Manifest.toml`
  for the path.

# Julia style guide

- avoid being unnecessarily restrictive about method arguments. `f(A::Matrix{Float64})`
  silently excludes sparse matrices, GPU arrays, `Float32`, dual numbers, and anything
  else that would work fine — the caller gets a confusing `MethodError` instead.
  Annotate only as specifically as the implementation requires: use `Matrix{Float64}`
  only when a `ccall` or similar demands a specific memory layout and element type;
  use `AbstractMatrix` when 2-D structure matters; use `AbstractArray` when it does
  not; leave unannotated when the method works for any input. Annotate to control
  dispatch and resolve ambiguities, not to document intent.

- the same caution applies to parametric `struct` constructors. Write the inner
  constructor with *unconstrained* value arguments — `MyStruct{A,B}(a, b) where {A,B}`,
  not `(a::A, b::B)` — and let the field declarations and `new` do the
  coercion; constraining the arguments breaks calls like `MyStruct{Float64}(1, 0)`.
  Outer constructors should only compute type parameters and delegate inward,
  forming a cascade `MyStruct(args...)` → `MyStruct{A}(args...)` →
  `MyStruct{A,B}(args...)` so every call form coerces identically. Some
  `struct`s have trailing type-parameters that are primarily internal,
  conferring inferrability but not usually manipulated by users; the cascade should
  leap over these by calling the inner constructor directly,
  `MyStruct{A,B}(args...)` → `MyStruct{A,B,typeof(c),typeof(d)}(args...)`, where
  `c` and `d` have already been `convert`ed to types consistent with `A` and
  `B`, e.g., `c = convert(AbstractArray{A}, c)::AbstractArray{A}` given
  `C<:AbstractArray{A}`.

- avoid redundant keyword syntax: when a variable name matches the keyword argument
  name, use the short form `f(; max_iter)` instead of `f(; max_iter=max_iter)`.
  This applies at function call sites, `NamedTuple` construction, and similar contexts.
  Exception: packages supporting Julia before 1.6 must use the long form.

- `@test_throws SomeExceptionType expr` may be worth testing when
  `SomeExceptionType` provides meaning, but
  `@test_throws "message that clearly explains the problem to users" expr` is
  typically the more relevant target for testing. There are cases where it may
  be reasonable test both.

# Devops

- I dislike jargony comments in code or tests. When fixing latent bugs, I've
  seen agents frequently tag them "Regression: blah blah". Provide a statement
  of intent instead. Bug history is only rarely relevant, avoid "Formerly
  this..." unless the explanation seems likely to be effective in heading off
  future misguided changes.

- Changes motivated by GitHub issues or prs should include a comment with the
  corresponding issue number. 
