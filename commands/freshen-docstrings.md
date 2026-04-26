---
description: Audit and improve Julia package docstrings: find missing/outdated docs on exported and public symbols, using Base.Docs.meta for context-efficient gap detection
---

## 1. Identify symbols requiring docstrings

The full set of symbols requiring docstrings is: all exported names plus all public-but-not-exported names. Detecting public-but-not-exported symbols requires Julia 1.11+, so always run this step with `julia +1 --project` in case the user's default Julia version is older than this.

```julia
M = SomeModule  # replace with the actual module name

# Symbols with docstrings — Docs.Binding keys carry a .var Symbol
documented = Set(b.var for b in keys(Base.Docs.meta(M)))

# All symbols that need docstrings
exported = Set(names(M))
public_not_exported = filter(s -> Base.ispublic(M, s) && !Base.isexported(M, s), names(M; all=true))
needs_docstring = exported ∪ Set(public_not_exported)

# Gap
undocumented = filter(s -> s ∉ documented, collect(needs_docstring))
```

## 2. Audit existing docstrings

In a subagent, extract all docstrings from the meta dict and audit them. The docstring text is already available in the meta dict — do not read source files for the audit:

```julia
# Dump all docstrings with their current method signatures
for (binding, multidoc) in Base.Docs.meta(M)
    for (sig, docstr) in multidoc.docs
        println("=== ", binding.var, " :: ", sig, " ===")
        println(docstr.text[1])
    end
end
```

For signature accuracy, cross-check against live method signatures:

```julia
# e.g. for a specific function
methods(M.foo)
```

Check each docstring for:
- Outdated argument lists (compare docstring signatures against `methods()` output)
- Missing return-value description
- Clarity, conciseness, and standard Julia docstring style (indented signatures, backtick-quoted names, etc.)

If a specific issue requires implementation context to resolve, use the `:path` and `:linenumber` fields from `docstr.data` to read only the relevant lines — but only in a fresh Julia session, as Revise does not update these fields when source is edited.

The subagent should return a structured list: for each symbol with issues, the symbol name, issue type (outdated signature / missing return description / style / clarity), and a brief note describing the problem.

Related methods of the same function can share a single docstring using a multi-signature first line:

```julia
"""
    foo(name::AbstractString)
    foo(mod::Module)

Check a module for any misuses of `bar`.
"""
```

Reserve separate docstrings for methods that differ substantially in behavior or purpose.

## 3. Summarize findings

Report to the user:
- Symbols missing docstrings (listed, separated into exported vs. public-but-not-exported)
- Existing docstrings with issues (outdated signatures, clarity problems, style inconsistencies)

**[pause for approval]** Wait for the user to confirm which issues to fix before proceeding.

## 4. Implement and commit

Write new docstrings and fix approved issues.
