VERSION >= v"1.11" || error("Tests require Julia 1.11+ (current: $VERSION). Re-run with julia +1.")

using ClaudeUtils

# ---------------------------------------------------------------------------
# Test fixtures
#
# _ParentA / _WithDocs: exercises the bug — a module that adds a documented
# method to an external function.  Before the fix, the docstring was silently
# dropped because its typesig was Tuple{TypeA}, not Union{}.
#
# _ParentB / _WithoutDocs: control case — method added with no docstring at
# all, should still be reported as undocumented.
# ---------------------------------------------------------------------------

module _TestPkg

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
struct TypeB end
_ParentB.parent_fn_b(::TypeB) = 99
end # _WithoutDocs

end # _TestPkg

# ---------------------------------------------------------------------------
# Helpers
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

    @testset "documented method on extended function is not reported as missing" begin
        out = capture_audit(_TestPkg._WithDocs)
        @test !occursin("parent_fn_a has no docstring", out)
        @test occursin("Do something with a TypeA", out)
    end

    @testset "undocumented method on extended function is flagged" begin
        out = capture_audit(_TestPkg._WithoutDocs)
        @test occursin("has no docstring", out)
    end

end
