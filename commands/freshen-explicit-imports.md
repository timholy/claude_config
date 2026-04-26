---
description: Add ExplicitImports.jl to a Julia package, analyze import usage, fix problems, and add to the test suite
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

  In either case, add a version bound under `[compat]` with a lower bound compatible with the current LTS (currently Julia 1.10).

  Tip: I use `juliaup` to manage Julia versions, and `julia +1 --project ...` runs the current release (currently 1.12).

## 2. Run ExplicitImports analysis

In a subagent running Julia 1.11 or higher, evaluate:

```julia
using TestEnv
TestEnv.activate()
using <PackageModule>, ExplicitImports
print_explicit_imports(<PackageModule>; report_non_public=true)
```

where `<PackageModule>` is the name of the package defined in this repository.

## 3. Report and fix

Summarize the results for the user. Propose fixes for any detected problems (e.g., reliance on non-public API, implicit imports that should be made explicit). Wait for user approval before making changes.

## 4. Add to test suite

Once issues are resolved, add `test_explicit_imports` to the test suite (inside the main `@testset` block) to prevent regressions.

Commit all changes.
