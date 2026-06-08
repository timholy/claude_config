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
  Exceptions:
  + When debugging/developing non-Revisable packages. These include Revise itself
    and its dependencies.
  + For measurement/benchmarking work where each run is a one-shot fresh process
    (cold package-load timing, invalidation analysis, etc.). Particularly for
    invalidation analyses, loading Revise can perturb results and cause confusion.
  In such cases, run julia directly from the shell.

- Use `Pkg.test()` for a final run only when ready to submit a pull request.

# Graphical display (Makie, Gtk, Qt, …)

Decide **at session start**, before loading any plotting backend, whether the
work is interactive or headless. Switching later requires reloading the
backend, and restarting the session to switch discards accumulated state
(loaded packages, data, open figures).

Check what's available first:

    get(ENV, "DISPLAY", "")   # ":0" => a real monitor is available (e.g. WSLg)

- **Interactive (default for analysis/exploration).** When a real display is
  present, the MCP session inherits it automatically — do *not* override
  `DISPLAY`:

      using GLMakie; GLMakie.activate!()
      display(fig)   # live window on the monitor; persists/updates across eval calls

- **Headless (CI-like batch, final `Pkg.test()`, profiling, or no real
  display).** Either render to files with a non-interactive backend
  (CairoMakie → PNG/SVG), or start a virtual display once and point the session
  at it *before* loading the backend:

      # Bash: Xvfb :99 -screen 0 1024x768x24 &
      ENV["DISPLAY"] = ":99"

  Fall back to `xvfb-run julia ...` via Bash only for final `Pkg.test()` runs or
  when the MCP session cannot be reconfigured.

Only spin up Xvfb when no real display is present or you explicitly want
headless output — on a desktop session the inherited `:0` already shows
figures on the monitor.

# Julia packages

- Use the local `Project.toml` environment when available. Revise, TestEnv,
  Cthulhu, and some other developer-oriented tools are in my global (fallback)
  environment.

- Do not bias decisions about packages based on what is already installed.

- When adding new packages to a local project, also update the `[compat]`
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

- Do not post comments on GitHub without getting my approval for the exact text.
  GitHub is also a social media environment and I do not want you representing
  me without consent.

- Comments, docstrings, and commit messages must stand on their own for a reader
  who has only the repository: state what *is* true about the code now, not its
  history, its motivation, or the plan it came from. This is a frequent failure
  point — re-read the diff's comments before proposing a commit. Full guidance
  and examples: `rules/code-comments.md`.

- Commit subject lines should ideally be shorter than lines in the body (aim for
  <=50, up to 72 OK) due to formatting on GitHub.

- Changes motivated by GitHub issues or prs should include a comment with the
  corresponding issue number. Do not put the issue number in the subject line,
  as that can be confusing in conjunction with a merge-squash that inserts the
  PR# in the subject. If the commit fixes an issue, do put "Fixes #xyz" or
  similar in the body of the commit message; that will trigger GitHub to
  auto-close the issue. If a commit closes multiple issues, you cannot provide
  ranges or comma-separated lists of numbers; use "Fixes #abc; fixes #def; ..."
  