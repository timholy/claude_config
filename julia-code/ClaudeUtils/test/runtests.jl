VERSION >= v"1.11" || error("Tests require Julia 1.11+ (current: $VERSION). Re-run with julia +1.")

using ClaudeUtils

# ---------------------------------------------------------------------------
# Test fixtures
# ---------------------------------------------------------------------------

module _TestPkg

# --- Extending external functions ---

module _ParentA
export parent_fn_a
function parent_fn_a end
end

module _ParentB
export parent_fn_b
function parent_fn_b end
end

module _WithDocs
import .._ParentA
export parent_fn_a, TypeA
const parent_fn_a = _ParentA.parent_fn_a
"A test type."
struct TypeA end
"""
    parent_fn_a(x::TypeA)

Do something with a TypeA.
"""
_ParentA.parent_fn_a(::TypeA) = 42
end # _WithDocs

module _WithoutDocs
import .._ParentB
export parent_fn_b, TypeB
const parent_fn_b = _ParentB.parent_fn_b
"A test type."
struct TypeB end
_ParentB.parent_fn_b(::TypeB) = 99
end # _WithoutDocs

# --- Module-owned functions ---

module _OwnedFns
export documented_fn, undocumented_fn, per_method_fn

"""
    documented_fn(x)

A well-documented function.
"""
documented_fn(x) = x

undocumented_fn(x) = x

"""
    per_method_fn(x::Int)

Handle an integer input.
"""
per_method_fn(x::Int) = x * 2

"""
    per_method_fn(x::String)

Handle a string input.
"""
per_method_fn(x::String) = x * "!"
end # _OwnedFns

# --- Module-level docstring ---

"""A module with its own docstring."""
module _DocModule
export mod_fn
"""
    mod_fn()

Return nothing.
"""
mod_fn() = nothing
end # _DocModule

# --- No module-level docstring ---

module _NoDocModule
export nodoc_fn
"""
    nodoc_fn()

A documented function in an undocumented module.
"""
nodoc_fn() = nothing
end # _NoDocModule

# --- Submodule recursion ---

module _Outer
export outer_fn, _Inner
"""
    outer_fn()

The outer function.
"""
outer_fn() = "outer"

module _Inner
export inner_fn
"""
    inner_fn()

The inner function.
"""
inner_fn() = "inner"
end # _Inner
end # _Outer

# --- Type alias with its own docstring ---

module _WithAlias
export BaseType, AliasType
"""
    BaseType{T}

The base type.
"""
struct BaseType{T}
    x::T
end
"""
    AliasType

A type alias for `BaseType{Int}` with its own distinct docstring.
"""
const AliasType = BaseType{Int}
end # _WithAlias

# --- Generic binding (constant) ---

module _WithConst
export THE_ANSWER
"The answer to life, the universe, and everything."
const THE_ANSWER = 42
end # _WithConst

end # _TestPkg

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

function capture_audit(mod, top=mod)
    buf = IOBuffer()
    audit_docstrings(mod, top, buf)
    String(take!(buf))
end

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

using Test

@testset "audit_docstrings" begin

    @testset "extending external function: documented method is not flagged" begin
        out = capture_audit(_TestPkg._WithDocs)
        @test !occursin("parent_fn_a has no docstring", out)
        @test occursin("Do something with a TypeA", out)
    end

    @testset "extending external function: undocumented method is flagged" begin
        out = capture_audit(_TestPkg._WithoutDocs)
        @test occursin("parent_fn_b has no docstring", out)
    end

    @testset "owned function: docstring is shown" begin
        out = capture_audit(_TestPkg._OwnedFns)
        @test occursin("A well-documented function", out)
        @test !occursin("Function documented_fn has no docstring", out)
    end

    @testset "owned function: missing docstring is flagged" begin
        out = capture_audit(_TestPkg._OwnedFns)
        @test occursin("undocumented_fn has no docstring", out)
    end

    @testset "per-method docstrings on owned function" begin
        out = capture_audit(_TestPkg._OwnedFns)
        @test occursin("Handle an integer input", out)
        @test occursin("Handle a string input", out)
    end

    @testset "module-level docstring is shown" begin
        out = capture_audit(_TestPkg._DocModule)
        @test occursin("A module with its own docstring", out)
        @test !occursin("_DocModule has no docstring", out)
    end

    @testset "missing module-level docstring is flagged" begin
        out = capture_audit(_TestPkg._NoDocModule)
        @test occursin("has no docstring", out)
        # But the owned function inside is still documented
        @test occursin("A documented function in an undocumented module", out)
    end

    @testset "submodule recursion" begin
        out = capture_audit(_TestPkg._Outer)
        @test occursin("The outer function", out)
        @test occursin("The inner function", out)
        # Both module boundaries appear
        @test occursin("Auditing module", out)
        ms = findall("Auditing module", out)
        @test length(ms) >= 2
    end

    @testset "type alias shows its own docstring, not the base type's" begin
        out = capture_audit(_TestPkg._WithAlias)
        @test occursin("A type alias for", out)
        @test !occursin("Function AliasType has no docstring", out)
        # The alias docstring and base type docstring are distinct
        alias_pos = findfirst("A type alias for", out)
        base_pos  = findfirst("The base type", out)
        @test !isnothing(alias_pos)
        @test !isnothing(base_pos)
        @test alias_pos != base_pos
    end

    @testset "generic binding (constant) is shown" begin
        out = capture_audit(_TestPkg._WithConst)
        @test occursin("THE_ANSWER", out)
        @test occursin("Generic binding", out)
    end

    @testset "output structure markers" begin
        out = capture_audit(_TestPkg._OwnedFns)
        @test occursin("----- Auditing module", out)
        @test occursin("----- Done auditing module", out)
        @test occursin("\n---", out)   # function block delimiter
        @test occursin("\n--\n", out)  # method block delimiter
    end

end
