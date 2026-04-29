---
description: Audit and improve Julia package docstrings: find missing/outdated docs on exported and public symbols, using Base.Docs.meta for context-efficient gap detection
model: sonnet
effort: medium
---

## 1. Audit docstrings

Run the "docstring-auditor" subagent and process the output.

## 2. Summarize findings

Report to the user:
- Symbols missing docstrings (listed, separated into exported vs. public-but-not-exported)
- Existing docstrings with issues (outdated signatures, clarity problems, style inconsistencies, missing examples)

Conclude with a summary of recommendations about any changes that cross threshold for utility to the users of the package.

**[pause for approval]** Wait for the user to confirm which issues to fix before proceeding.

## 3. Implement

Write new docstrings and fix approved issues. When making changes, instead of reading full source files, where possible use targeted reads/writes using the file and line numbers extracted during the audit. To avoid changing line numbers for future edits, this may require you to edit files starting at the end and working your way towards the beginning.

Any examples should be tested via MCP to be certain they work. You may take it for granted that the user has issued `using M` prior to running the example. Other setup, module-qualification, etc., should be spelled out.

After writing examples, check whether the package has a `docs/` directory with a Documenter.jl build. If it does, the doctests will be exercised there. If it does not, check `test/runtests.jl` and add doctest coverage if absent: add `Documenter` as a test dependency in `Project.toml` (in `[extras]` and `[targets]`, with a `[compat]` entry of `"1"`), then add to `runtests.jl`:
```julia
using Documenter
DocMeta.setdocmeta!(MyPackage, :DocTestSetup, :(using MyPackage); recursive=true)
@testset "Doctests" begin
    doctest(MyPackage)
end
```
Adjust the `DocTestSetup` expression to include any additional packages needed by the examples (e.g. `using MyPackage, SomeDep`).
