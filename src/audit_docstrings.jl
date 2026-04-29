VERSION >= v"1.11" || error("audit_docstrings requires a recent Julia release (current: $VERSION). Re-run with julia_cmd=\"julia +1\".")

function audit_docstrings(mod::Module, top::Module=mod)
    println("----- Auditing module: $(mod)")
    # Check for a module-level docstring
    doc = Base.Docs.doc(mod)
    if doc !== nothing
        c = first(doc.content)
        str = sprint(show, c)
        if occursin("No docstring", str)
            println("\nModule $(mod) has no docstring.")
        else
            println("\nModule $(mod):\n$(str)")
        end
    else
        println("\nModule $(mod) has no docstring.")
    end
    for name in names(mod)   # public names only
        obj = getglobal(mod, name)
        if isa(obj, Function) || isa(obj, Type)
            println("\n---")
            doc = Base.Docs.doc(obj)
            if doc === nothing
                println("\nFunction $(name) has no docstring.")
            else
                if isempty(doc.meta[:results])
                    println("\nFunction $(name) has no docstring.")
                    continue
                end
                # First check for a function-level docstring
                for res in doc.meta[:results]
                    inmodule(res.data[:module], top) || continue
                    sig = Base.unwrap_unionall(res.data[:typesig])
                    if sig === Union{}
                        path, line = res.data[:path], res.data[:linenumber]
                        if length(res.text) == 1
                            doc = only(res.text)
                            println("\nFunction $(name) ($path:$line):\n$(doc)")
                        else
                            println("\nFunction $(name) ($path:$line) has a docstring with multiple parts, raw output:\n$(doc)")
                        end
                    end
                end
                # Now methods
                for m in methods(obj)
                    inmodule(m.module, top) || continue
                    doc = Base.Docs._doc(obj, m.sig)
                    if isa(doc, Base.Docs.DocStr) &&
                            Tuple{Base.unwrap_unionall(m.sig).parameters[2:end]...} <: doc.data[:typesig]
                        str = only(doc.text)
                        println("\n--\nMethod $(m):\n$(str)")
                    else
                        println("\n--\nMethod $(m): (no method-specific docstring)")
                    end
                end
            end
        elseif isa(obj, Module)
            # Recursively audit submodules
            obj !== mod && audit_docstrings(obj, top)
        else
            doc = Base.Docs.doc(Base.Docs.Binding(mod, name))
            println("\n---- Generic binding $(doc.meta[:binding]):")
            for item in doc.content
                str = sprint(show, item)
                println(str)
            end
        end
    end
    println("----- Done auditing module: $(mod)")
end

function inmodule(mod::Module, top::Module)
    mod === top && return true
    while (parent = parentmodule(mod)) !== mod
        parent === top && return true
        mod = parent
    end
    return false
end
