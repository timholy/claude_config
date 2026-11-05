# Summarize the provenance of every result unit under one or more result roots.
#
#     julia provenance_report.jl ROOT [ROOT...] > provenance_report.md
#
# Reads the `<path>.prov.toml` sidecars and `<root>/provenance/*.toml` records
# written by `provenance.jl`, and reports, in Markdown:
#   - result units by tier, environment, host, Julia version and date;
#   - for each package and source path, the distinct commits (and dirty states)
#     the units were produced with, and which match the current working tree;
#   - source files whose content at run time differs from the current file;
#   - units with incomplete provenance, and files with no sidecar.
#
# The report describes; it does not judge. Its findings never change the exit
# status, so it is safe to call from any build or script. Deciding whether a set
# of results is fit for submission is the author's call.

using TOML, SHA

const UNKNOWN = "unknown"

function trygit(dir, args...)
    try
        return String(strip(read(pipeline(Cmd(`git $args`; dir = dir); stderr = devnull), String)))
    catch
        return nothing
    end
end

short(c) = c isa AbstractString && length(c) >= 10 && c != UNKNOWN ? c[1:10] : string(c)

function gitlabel(st)
    c = short(get(st, "commit", UNKNOWN))
    d = get(st, "dirty", UNKNOWN)
    return d === true ? "$c (dirty)" : d === false ? c : "$c (dirty: unknown)"
end

function pkglabel(p)
    haskey(p, "commit") && return gitlabel(p)
    v = get(p, "version", UNKNOWN)
    t = get(p, "git-tree-sha1", nothing)
    return t === nothing ? "v$v" : "v$v tree $(short(t))"
end

current_head(path) = isdir(path) ? trygit(path, "rev-parse", "HEAD") : nothing

function current_hash(file)
    isfile(file) || return nothing
    try
        return bytes2hex(sha256(read(file)))[1:16]
    catch
        return nothing
    end
end

function load_root(root)
    records = Dict{String,Any}()
    pdir = joinpath(root, "provenance")
    if isdir(pdir)
        for f in readdir(pdir)
            endswith(f, ".toml") || continue
            try
                records[f[1:end-5]] = TOML.parsefile(joinpath(pdir, f))
            catch err
                println(stderr, "unreadable record $f: ", sprint(showerror, err))
            end
        end
    end
    stamps = Pair{String,Dict{String,Any}}[]
    unstamped = String[]
    for (dir, subdirs, files) in walkdir(root)
        filter!(d -> !(d == "provenance" && dir == root) && !startswith(d, "."), subdirs)
        fileset = Set(files)
        for f in files
            full = joinpath(dir, f)
            if endswith(f, ".prov.toml")
                try
                    push!(stamps, full[1:end-10] => TOML.parsefile(full))
                catch err
                    println(stderr, "unreadable sidecar $full: ", sprint(showerror, err))
                end
            elseif !endswith(f, ".tmp") && !(f * ".prov.toml" in fileset)
                push!(unstamped, relpath(full, root))
            end
        end
    end
    return records, stamps, unstamped
end

duration(s) = s < 120 ? "$(round(s; digits = 1)) s" : s < 7200 ? "$(round(s / 60; digits = 1)) min" :
              "$(round(s / 3600; digits = 1)) h"

tally!(d, k, n = 1) = (d[k] = get(d, k, 0) + n)

function table(io, header, rows)
    println(io, "| ", join(header, " | "), " |")
    println(io, "|", repeat(" --- |", length(header)))
    for r in rows
        println(io, "| ", join(r, " | "), " |")
    end
    println(io)
end

function report(io, root)
    records, stamps, unstamped = load_root(root)
    println(io, "# Provenance report: `", root, "`\n")
    if isempty(stamps)
        println(io, "No result units with provenance sidecars were found.\n")
    end

    by_id = Dict{String,Int}()
    tiers = Dict{String,Int}()
    written = String[]
    total_wall = 0.0
    for (_, s) in stamps
        tally!(by_id, string(get(s, "provenance", UNKNOWN)))
        tally!(tiers, string(get(s, "tier", UNKNOWN)))
        haskey(s, "written") && push!(written, string(s["written"]))
        w = get(s, "wall_seconds", nothing)
        w isa Real && (total_wall += w)
    end
    missing_ids = [id for id in keys(by_id) if !haskey(records, id)]

    println(io, "## Summary\n")
    println(io, "- Result units: ", length(stamps))
    println(io, "- Tiers: ", join(["$t ($n)" for (t, n) in sort(collect(tiers))], ", "))
    println(io, "- Distinct provenance records: ", length(by_id))
    isempty(written) || println(io, "- Written between ", minimum(written), " and ", maximum(written))
    total_wall > 0 && println(io, "- Summed compute time of the units: ", duration(total_wall))
    for key in ("hostname", "julia", "cpu")
        vals = Dict{String,Int}()
        for (id, n) in by_id
            haskey(records, id) && tally!(vals, string(get(records[id], key, UNKNOWN)), n)
        end
        println(io, "- ", key, ": ", join(["$v ($n)" for (v, n) in sort(collect(vals))], ", "))
    end
    println(io)

    # Packages
    pkgnames = Set{String}()
    for r in values(records)
        union!(pkgnames, keys(get(r, "packages", Dict())))
    end
    rows = Vector{String}[]
    for name in sort(collect(pkgnames))
        labels = Dict{String,Int}()
        current = Dict{String,Bool}()
        for (id, n) in by_id
            haskey(records, id) || continue
            p = get(get(records[id], "packages", Dict()), name, nothing)
            p === nothing && continue
            lab = pkglabel(p)
            tally!(labels, lab, n)
            if haskey(p, "path") && !haskey(current, lab)
                head = current_head(p["path"])
                current[lab] = head !== nothing && get(p, "commit", "") == head
            end
        end
        length(labels) == 1 && isempty(current) && continue   # uniform registered package: not interesting
        for (lab, n) in sort(collect(labels); by = last, rev = true)
            cur = haskey(current, lab) ? (current[lab] ? "yes" : "no") : ""
            push!(rows, [name, lab, string(n), cur])
        end
    end
    println(io, "## Packages\n")
    if isempty(rows)
        println(io, "Every unit used the same version of every recorded package.\n")
    else
        println(io, "Packages that were `dev`ed or varied across units. ",
                "\"Current\" compares a `dev`ed package's commit with its checkout now.\n")
        table(io, ["Package", "Revision", "Units", "Current HEAD"], rows)
    end

    # Sources
    println(io, "## Harness sources\n")
    srcrows = Vector{String}[]
    changed = Dict{String,Int}()
    for (id, n) in by_id
        haskey(records, id) || continue
        for (path, st) in get(records[id], "sources", Dict())
            push!(srcrows, [path, gitlabel(st), string(n)])
            for (f, h) in get(st, "files", Dict())
                full = isfile(path) ? path : joinpath(path, f)
                cur = current_hash(full)
                cur == h || tally!(changed, full * (cur === nothing ? " (deleted)" : ""), n)
            end
        end
    end
    if isempty(srcrows)
        println(io, "No source paths were recorded.\n")
    else
        merged = Dict{Tuple{String,String},Int}()
        for r in srcrows
            tally!(merged, (r[1], r[2]), parse(Int, r[3]))
        end
        table(io, ["Source path", "Commit", "Units"],
              [[p, c, string(n)] for ((p, c), n) in sort(collect(merged))])
        if isempty(changed)
            println(io, "Every recorded source file matches its current content.\n")
        else
            println(io, "Source files whose current content differs from what produced some units:\n")
            table(io, ["File", "Units produced with other content"],
                  [[f, string(n)] for (f, n) in sort(collect(changed); by = last, rev = true)])
        end
    end

    # Gaps
    println(io, "## Incomplete provenance\n")
    any_gap = false
    for (id, n) in sort(collect(by_id))
        haskey(records, id) || continue
        errs = get(records[id], "errors", String[])
        isempty(errs) && continue
        any_gap = true
        println(io, "- Record `", id, "` (", n, " units): ", join([first(split(e, '\n')) for e in errs], "; "))
    end
    if !isempty(missing_ids)
        any_gap = true
        println(io, "- Sidecars refer to records not present in `provenance/`: ",
                join(["`$id` ($(by_id[id]) units)" for id in sort(missing_ids)], ", "))
    end
    if !isempty(unstamped)
        any_gap = true
        shown = first(sort(unstamped), 10)
        println(io, "- ", length(unstamped), " files have no sidecar (derived tables and logs may ",
                "legitimately lack one): ", join(["`$f`" for f in shown], ", "),
                length(unstamped) > 10 ? ", ..." : "")
    end
    any_gap || println(io, "None.")
    println(io)
end

for root in (isempty(ARGS) ? ["."] : ARGS)
    report(stdout, abspath(root))
end
