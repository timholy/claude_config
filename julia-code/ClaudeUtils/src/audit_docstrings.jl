
function audit_docstrings(mod::Module, top::Module=mod, io::IO=stdout)
    Base.VERSION >= v"1.11" || error("audit_docstrings requires a recent Julia release (current: $VERSION). Re-run with julia_cmd=\"julia +1\".")
    println(io, "----- Auditing module: $(mod)")
    # Check for a module-level docstring
    doc = Base.Docs.doc(mod)
    if doc !== nothing
        c = first(doc.content)
        str = sprint(show, c)
        if occursin("No docstring", str)
            println(io, "\nModule $(mod) has no docstring.")
        else
            println(io, "\nModule $(mod):\n$(str)")
        end
    else
        println(io, "\nModule $(mod) has no docstring.")
    end
    for name in names(mod)   # public names only
        obj = getglobal(mod, name)
        if isa(obj, Function) || isa(obj, Type)
            println(io, "\n---")
            doc = Base.Docs.doc(obj)
            if doc === nothing
                println(io, "\nFunction $(name) has no docstring.")
            else
                if isempty(doc.meta[:results])
                    println(io, "\nFunction $(name) has no docstring.")
                    continue
                end
                # Check for function-level docstrings (Union{} sig) and module-specific method docs
                for res in doc.meta[:results]
                    inmodule(res.data[:module], top) || continue
                    path, line = res.data[:path], res.data[:linenumber]
                    if length(res.text) == 1
                        doc_text = only(res.text)
                        println(io, "\nFunction $(name) ($path:$line):\n$(doc_text)")
                    else
                        println(io, "\nFunction $(name) ($path:$line) has a docstring with multiple parts, raw output:\n$(res)")
                    end
                end
                # Now methods
                for m in methods(obj)
                    inmodule(m.module, top) || continue
                    mdoc = Base.Docs._doc(obj, m.sig)
                    method_args = Tuple{Base.unwrap_unionall(m.sig).parameters[2:end]...}
                    if !(isa(mdoc, Base.Docs.DocStr) && method_args <: mdoc.data[:typesig])
                        # _doc didn't find a match; scan module results for a covering doc
                        mdoc = nothing
                        for res in doc.meta[:results]
                            inmodule(res.data[:module], top) || continue
                            if method_args <: Base.unwrap_unionall(res.data[:typesig])
                                mdoc = res
                                break
                            end
                        end
                    end
                    if mdoc !== nothing
                        str = only(mdoc.text)
                        println(io, "\n--\nMethod $(m):\n$(str)")
                    else
                        println(io, "\n--\nMethod $(m): (no method-specific docstring)")
                    end
                end
            end
        elseif isa(obj, Module)
            # Recursively audit submodules
            obj !== mod && audit_docstrings(obj, top, io)
        else
            doc = Base.Docs.doc(Base.Docs.Binding(mod, name))
            println(io, "\n---- Generic binding $(doc.meta[:binding]):")
            for item in doc.content
                str = sprint(show, item)
                println(io, str)
            end
        end
    end
    println(io, "----- Done auditing module: $(mod)")
end

function inmodule(mod::Module, top::Module)
    mod === top && return true
    while (parent = parentmodule(mod)) !== mod
        parent === top && return true
        mod = parent
    end
    return false
end
