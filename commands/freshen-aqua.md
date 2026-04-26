---
description: Add Aqua.jl to a Julia package's test dependencies, run quality checks, report findings, and add to the test suite
---

## 1. Add Aqua.jl as a test dependency

Check how test dependencies are currently specified in this project:

- **If `test/Project.toml` exists**, add Aqua via:
  ```
  julia --project=test -e 'using Pkg; Pkg.add("Aqua")'
  ```
  and update the `[compat]` section of `test/Project.toml`.

- **If the root `Project.toml` uses `[extras]`/`[targets]`**, check the Julia compat lower bound:
  - **Julia 1.11+**: `julia --project -e 'using Pkg; Pkg.add("Aqua"; target=:extras)'`
  - **Julia 1.10**: `julia --project -e 'using Pkg; Pkg.add("Aqua")'`, then manually move the Aqua entry from `[deps]` to `[extras]` and add `"Aqua"` to the `test` list under `[targets]`.

  In either case, add a version bound under `[compat]` with a lower bound compatible with Julia 1.10 (LTS).

## 2. Run Aqua checks

Run:

```julia
using TestEnv
TestEnv.activate()
using <PackageModule>, Aqua
Aqua.test_all(<PackageModule>)
```

where `<PackageModule>` is the name of the package defined in this repository.

## 3. Report and fix

Summarize the results for the user. Propose fixes for any failures. Wait for user approval before making changes.

## 4. Add to test suite

Once all Aqua checks pass, add `Aqua.test_all(<PackageModule>)` to the test suite (inside the main `@testset` block) to prevent regressions.

## 5. Add Aqua badge to README

Add the following badge to the README (after any existing badges):

```
[![Aqua QA](https://juliatesting.github.io/Aqua.jl/dev/assets/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
```

Commit all changes.
