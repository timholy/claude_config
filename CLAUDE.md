# Debugging Julia code

This assumes usage of the MCP server. Tips:
- Exploit `Revise` to amortize the cost of compilation
- Many packages require `TestEnv` to run their tests in an interactive session
- Exploit `Revise` to instrument (and reinstrument) code to capture data triggering bugs. Example:

```julia
module MyPackage

debugdata = Ref{Any}()   # will hold captured data

function broken(args...)
    #= some code here =#
    # Begin instrumentation
    # This used to be `x = do_something(args...)` but that occasionally throws an error
    x = try
        do_something(args...)
    catch e
        debugdata[] = (deepcopy(args[1], ...))
        rethrow(e)
    end
    # End instrumentation
    #= more code =#
end

end
```

Then you inspect `debugdata[]` in the interactive session to learn more about the arguments triggering the error. Revise lets you iterate this process using different instrumentation points.

# Style guide

- avoid being unnecessarily restrictive about method arguments: for example,
  `f(A::Matrix{Float64})` is usually too specific unless you have good reasons
  (e.g., `f` will `ccall` code that expects a particular memory layout).
  `f(A::AbstractMatrix)` is typically a better choice. Foremost, signatures
  should be specific enough to control dispatch and resolve ambiguities.
  Judicious annotation can also make code easier to read.

- avoid redundant keyword syntax: if `f` accepts a kwarg called `max_iter`
  and you already have an in-scope variable `max_iter`, then calling it as
  `f(; max_iter)` suffices; don't write this as `f(; max_iter=max_iter)`.
  Exception: packages that still support Julia 1.0 need to write it the long way.

- when adding packages to a project, don't insert the SHA from your own
  knowledge: use Julia's package manager. Also update the `[compat]` section of
  `Project.toml` to bound the version of the new dependency. Where possible,
  choose lower bounds compatible with the LTS release of Julia (currently 1.10).

- any new `convert(::Type{T}, x)` methods should always return an object of the
  requested type `T`. You should mentally model this as
  `convert(::Type{T}, x)::T`. If the caller writes `convert(Vector{Real}, list)`,
  the return type should be `Vector{Real}` and not `Vector{T}` for some concrete
  `T<:Real`. The same goes for type-constructors.
