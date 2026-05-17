---
description: Add ExplicitImports.jl to a Julia package, analyze import usage, fix problems, and add to the test suite
model: Sonnet
effort: low
---

## 1. Add ExplicitImports.jl as a test dependency

Check how test dependencies are currently specified in this project:

- **If `test/Project.toml` exists**, add ExplicitImports via:
  ```
  julia --project=test -e 'using Pkg; Pkg.add("ExplicitImports")'
  ```
  and update the `[compat]` section of `test/Project.toml`.

- **If the root `Project.toml` uses `[extras]`/`[targets]`**, check the Julia compat lower bound:
  - **Julia 1.11+**: `julia --project -e 'using Pkg; Pkg.add("ExplicitImports"; target=:extras)'`
  - **Julia 1.10**: `julia --project -e 'using Pkg; Pkg.add("ExplicitImports")'`, then manually move the entry from `[deps]` to `[extras]` and add `"ExplicitImports"` to the `test` list under `[targets]`.

  In either case, add a `[compat]` bound for ExplicitImports. Set the lower bound to the minor version `Pkg.add` just installed — read it straight from the install output (`ExplicitImports v1.15.0` → `ExplicitImports = "1.15"`). Do **not** use a looser bound like `"1"`: step 4 uses `test_explicit_imports`, which only exists from v1.15 onward, so an older resolved version would break the suite with an `UndefVarError`. A tight lower bound is harmless here — ExplicitImports is a test-only dependency, so it never constrains which Julia or package versions users can install.

  Tip: I use `juliaup` to manage Julia versions, and `julia +1 --project ...` runs the current release (currently 1.12).

## 2. Run ExplicitImports analysis

`<PackageModule>` below is the name of the package defined in this repository.

Run the analysis on the **current Julia release** (`julia +1`, 1.11+). The
`public`/non-public distinction does not exist before 1.11, so this is the only
version on which all checks are authoritative:

```julia
using TestEnv
TestEnv.activate()
using <PackageModule>, ExplicitImports
print_explicit_imports(<PackageModule>; report_non_public=true)
test_explicit_imports(<PackageModule>)
```

`print_explicit_imports` gives a readable summary, centered on implicit and
non-public *imports*. `test_explicit_imports` is the call Step 4 installs as a
regression guard: it runs seven checks — implicit imports, stale explicit
imports, import and qualified-access ownership and public-ness, and
self-qualified accesses — several of which `print_explicit_imports` does not
surface. In particular, `check_all_qualified_accesses_are_public` flags
non-public *qualified accesses* such as `Base.Meta.parse`. Treat any failing
check as a problem to fix in Step 3 — do not rely on the
`print_explicit_imports` summary alone.

**Julia-version caveat.** The two public-ness checks
(`all_explicit_imports_are_public`, `all_qualified_accesses_are_public`)
determine "public" via `Base.ispublic` on Julia 1.11+, but fall back to
`Base.isexported` on older Julia. On a pre-1.11 Julia they therefore
*false-positive* on any binding that is `public` but not exported. So do not
analyse on a pre-1.11 Julia, and gate those two checks in the installed guard
(Step 4). The other five checks are version-robust.

## 3. Report and fix

Summarize the results for the user. Propose fixes for any detected problems (e.g., reliance on non-public API, implicit imports that should be made explicit). Wait for user approval before making changes.

Any code change must remain parseable on every supported Julia version. Notably, the `public` keyword is a syntax error before Julia 1.11, so declare public symbols with `@static if VERSION >= v"1.11"; eval(Expr(:public, :sym, ...)); end` rather than a literal `public` statement or `eval(Meta.parse("public ..."))` — `Expr(:public, ...)` builds the same AST using only public Base API, which the qualified-access check accepts.

## 4. Add to test suite and verify

Once issues are resolved, add `test_explicit_imports(<PackageModule>)` to the test suite to prevent regressions. Place it in its own `@testset "ExplicitImports"` block; if the suite already has a quality-checks testset (e.g. for Aqua), add it as a sibling alongside.

Check the `[compat] julia` lower bound in `Project.toml`. **If it is below 1.11**, gate the two public-ness checks by version so they run only where they are accurate (see the caveat in Step 2) — the other five checks still run on every version:

```julia
@testset "ExplicitImports" begin
    test_explicit_imports(<PackageModule>;
                          all_explicit_imports_are_public   = VERSION >= v"1.11",
                          all_qualified_accesses_are_public = VERSION >= v"1.11")
end
```

If the lower bound is already 1.11+, a plain `test_explicit_imports(<PackageModule>)` is fine.

Then run the full test suite and confirm it passes — on the current release, and, if the package supports it, on the lowest supported Julia version. With the gating above, both should be green. Do not finish this step with a red suite: if `test_explicit_imports` fails, return to Step 3.
