---
description: Run Julia test coverage analysis, identify gaps, propose new tests, and wait for user approval
---

## 1. Run tests with coverage

Run the test suite with coverage enabled:

```
julia --project --code-coverage=@ -e 'using Revise, TestEnv; TestEnv.activate(); include("test/runtests.jl")'
```

## 2. Analyze coverage

In a subagent, analyze the results using CoverageTools.jl:

```julia
import Pkg; Pkg.activate(; temp=true); Pkg.add("CoverageTools")
using CoverageTools
coverage = process_folder("src")
covered, total = get_summary(coverage)
println("Coverage: $(round(100*covered/total, digits=1))%")
for fc in coverage
    for (line, hits) in enumerate(fc.coverage)
        if hits === 0
            println("$(fc.filename):$line")
        end
    end
end
```

The subagent should return a compact summary: overall coverage percentage, then per-file uncovered line ranges grouped by proximity (e.g. "lines 42–48, 91" rather than a raw line-by-line dump). Aim for output a human can scan in under a minute.

## 3. Report findings

Summarize for the user:
- Overall coverage percentage
- Files/functions with meaningful gaps (ignore genuinely untestable code such as unreachable error paths)

## 4. Propose tests

Design tests to cover the gaps. Keep in mind:
- `@test_throws` should test the user-visible error message, not just the error type
- Printing tests should not be sensitive to whitespace changes
- Add `@inferred` for results used in performance-critical settings

**Wait for user approval before writing any tests.**

## 5. Implement approved tests

Delete all `.cov` files generated in step 1:
```
find . -name "*.jl.cov" -o -name "*.jl.*.cov" | xargs rm -f
```

Then add the approved tests to the test suite and verify they pass.

## 6. Re-check coverage

Re-run tests with coverage (step 1) and re-run the analysis (step 2) to verify the expected improvements. Clean up `.cov` files again before proceeding:
```
find . -name "*.jl.cov" -o -name "*.jl.*.cov" | xargs rm -f
```
