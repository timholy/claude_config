---
description: Update [compat] for a breaking dependency upgrade: verify baseline, bump compat, update, confirm resolver selection, fix breakage
---

Update the package in the current directory to allow a new breaking version of a dependency. The dependency name and new version should be specified by the user; ask if not provided.

## 1. Verify baseline

Run the test suite and confirm everything passes before making any changes:
```
julia --project -e 'using Revise, TestEnv; TestEnv.activate(); include("test/runtests.jl")'
```

**Do not proceed if any tests fail.** Report the failures to the user and stop.

## 2. Bump [compat]

In `Project.toml`, update the `[compat]` entry for the dependency to include the new version. Preserve the existing lower bound unless the user instructs otherwise.

## 3. Update and verify resolver selection

```
julia --project -e 'using Pkg; Pkg.update("<dependency>")'
```

Then confirm the resolver actually selected the new version:
```
julia --project -e 'using Pkg; Pkg.status("<dependency>")'
```

If the new version was not selected, report this to the user — the compat bounds or another dependency may be constraining the resolver.

## 4. Run tests and fix breakage

Run the test suite again. If tests fail, diagnose and fix the breakage. Repeat until tests pass.

Commit all changes (compat bump, any fixes) together with a message describing the dependency upgrade.
