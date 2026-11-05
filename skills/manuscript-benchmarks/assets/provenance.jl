# Provenance capture for benchmark results.
#
# Usage, once per process:
#
#     include("provenance.jl"); using .BenchProvenance
#     const PROV = BenchProvenance.capture(root; sources = [@__DIR__])
#     ... compute a result unit and write it to `path` ...
#     BenchProvenance.stamp(path, PROV; tier = "cheap", wall_seconds = t)
#
# `capture` writes one record per distinct environment to
# `<root>/provenance/<id>.toml` (content-addressed, so records from different
# runs and machines can be merged by copying the directory). `stamp` writes a
# small sidecar `<path>.prov.toml` naming that record, so every result unit
# carries its own provenance and a root assembled across many commits stays
# self-describing.
#
# Neither function throws. A field that cannot be determined is recorded as
# "unknown" with the reason in `errors`, and a warning is printed. Dirty trees,
# untracked files, unregistered or `dev`ed packages, and missing git are
# recorded, never rejected: judging whether a set of results is fit for
# submission belongs to the author, using `provenance_report.jl`.
#
# Dependencies are standard libraries only (TOML, SHA, Dates, LinearAlgebra). A
# package that `include`s this file must list them in its Project.toml.
module BenchProvenance

using TOML, SHA, Dates, LinearAlgebra

export capture, stamp

const UNKNOWN = "unknown"
const SOURCE_EXTENSIONS = (".jl", ".toml", ".R", ".py", ".sh", ".m")

struct Provenance
    id::String
    root::String
    record::Dict{String,Any}
end

function trygit(dir::AbstractString, args::AbstractString...)
    try
        return String(strip(read(pipeline(Cmd(`git $args`; dir = dir); stderr = devnull), String)))
    catch
        return nothing
    end
end

short_sha256(bytes) = bytes2hex(sha256(bytes))[1:16]

# Content-addressed copy under `<root>/provenance/<subdir>/`; returns the path relative to `root`.
function store_blob(root, subdir, content::AbstractString, ext)
    h = short_sha256(content)
    rel = joinpath("provenance", subdir, h * ext)
    full = joinpath(root, rel)
    if !isfile(full)
        mkpath(dirname(full))
        write(full, content)
    end
    return rel
end

"""
    git_state(root, path, errors) -> Dict

Commit, branch, and dirty state of the git working tree containing `path`, with
`git status` and `git diff` restricted to `path`. Only modifications to tracked
files count as dirty; untracked files are listed separately. When dirty, the
diff against `HEAD` is stored under `<root>/provenance/diffs/`, so the code that
ran can be reconstructed from the commit plus the diff.
"""
function git_state(root, path, errors)
    dir = isdir(path) ? path : dirname(abspath(path))
    commit = trygit(dir, "rev-parse", "HEAD")
    if commit === nothing
        push!(errors, "$path: not in a git working tree, or git unavailable")
        return Dict{String,Any}("commit" => UNKNOWN, "dirty" => UNKNOWN)
    end
    spec = abspath(path)
    st = Dict{String,Any}("commit" => commit)
    st["branch"] = something(trygit(dir, "rev-parse", "--abbrev-ref", "HEAD"), UNKNOWN)
    status = trygit(dir, "status", "--porcelain", "--untracked-files=no", "--", spec)
    if status === nothing
        push!(errors, "$path: git status failed")
        st["dirty"] = UNKNOWN
    else
        st["dirty"] = !isempty(status)
        if st["dirty"]
            diff = trygit(dir, "diff", "HEAD", "--", spec)
            diff === nothing || isempty(diff) || (st["diff"] = store_blob(root, "diffs", diff, ".diff"))
        end
    end
    untracked = trygit(dir, "ls-files", "--others", "--exclude-standard", "--", spec)
    if untracked !== nothing && !isempty(untracked)
        files = String.(split(untracked, '\n'))
        st["untracked"] = length(files) <= 20 ? files : vcat(files[1:20], "... $(length(files) - 20) more")
    end
    return st
end

function file_hashes(path)
    out = Dict{String,String}()
    if isfile(path)
        out[basename(path)] = short_sha256(read(path))
        return out
    end
    for (dir, subdirs, files) in walkdir(path)
        filter!(d -> !startswith(d, "."), subdirs)
        for f in files
            any(ext -> endswith(f, ext), SOURCE_EXTENSIONS) || continue
            full = joinpath(dir, f)
            out[relpath(full, path)] = short_sha256(read(full))
        end
    end
    return out
end

function manifest_file(projectfile)
    dir = dirname(projectfile)
    for name in ("Manifest-v$(VERSION.major).$(VERSION.minor).toml", "Manifest.toml",
                 "JuliaManifest.toml")
        p = joinpath(dir, name)
        isfile(p) && return p
    end
    return nothing
end

function manifest_deps(raw)
    deps = get(raw, "deps", raw)   # manifest format 2 nests under "deps"; format 1 does not
    out = Dict{String,Any}()
    for (name, entries) in deps
        entries isa AbstractVector && !isempty(entries) && (out[name] = first(entries))
    end
    return out
end

function package_record(root, name, entry, manifestdir, errors)
    rec = Dict{String,Any}()
    for key in ("version", "git-tree-sha1", "repo-url", "repo-rev", "repo-subdir")
        haskey(entry, key) && (rec[key] = entry[key])
    end
    if haskey(entry, "path")
        # `dev`ed package: the manifest records only a location, so the
        # revision has to be read from the working tree itself.
        path = entry["path"]
        full = isabspath(path) ? path : normpath(joinpath(manifestdir, path))
        rec["path"] = full
        merge!(rec, git_state(root, full, errors))
    end
    return rec
end

"""
    capture(root; sources = String[], packages = nothing, extra = Dict()) -> Provenance

Record the environment of the current process: Julia, host, CPU, threads, BLAS,
the active project's manifest (stored in full under `<root>/provenance/manifests/`),
version and tree hash of each package, the git state of each `dev`ed package,
and the git state and per-file content hashes of each path in `sources` (the
harness scripts and library code; keep result directories out of it).

`packages` lists the packages to describe; by default, the direct dependencies
of the active project. `extra` is merged into the record (for example the
configuration of the run).

Call once per process and reuse the result for every `stamp`.
"""
function capture(root::AbstractString; sources = String[], packages = nothing,
                 extra::AbstractDict = Dict{String,Any}())
    errors = String[]
    rec = Dict{String,Any}()
    section(f, what) = try
        f()
    catch err
        push!(errors, "$what: " * sprint(showerror, err))
    end

    section("system") do
        rec["julia"] = string(VERSION)
        rec["os"] = string(Sys.KERNEL, " ", Sys.MACHINE)
        rec["hostname"] = gethostname()
        cpus = Sys.cpu_info()
        rec["cpu"] = isempty(cpus) ? UNKNOWN : strip(cpus[1].model)
        rec["cpu_threads"] = Sys.CPU_THREADS
        rec["julia_threads"] = Threads.nthreads()
        rec["blas"] = string(BLAS.get_config())
        rec["blas_threads"] = BLAS.get_num_threads()
    end
    section("entry point") do
        rec["entry"] = Dict{String,Any}("program" => PROGRAM_FILE, "args" => copy(ARGS))
    end
    section("packages") do
        projectfile = Base.active_project()
        if projectfile === nothing || !isfile(projectfile)
            push!(errors, "no active project")
            return
        end
        rec["project"] = projectfile
        mfile = manifest_file(projectfile)
        if mfile === nothing
            push!(errors, "no manifest beside $projectfile")
            return
        end
        mtext = read(mfile, String)
        rec["manifest"] = store_blob(root, "manifests", mtext, ".toml")
        deps = manifest_deps(TOML.parse(mtext))
        names = packages === nothing ?
            collect(keys(get(TOML.parsefile(projectfile), "deps", Dict()))) : collect(packages)
        pkgs = Dict{String,Any}()
        for name in sort(names)
            entry = get(deps, name, nothing)
            if entry === nothing
                push!(errors, "$name: not in the manifest")
                pkgs[name] = Dict{String,Any}("version" => UNKNOWN)
            else
                pkgs[name] = package_record(root, name, entry, dirname(mfile), errors)
            end
        end
        rec["packages"] = pkgs
    end
    section("sources") do
        srcs = Dict{String,Any}()
        for s in sources
            key = abspath(s)
            if !ispath(key)
                push!(errors, "$s: no such path")
                continue
            end
            st = git_state(root, key, errors)
            st["files"] = file_hashes(key)
            srcs[key] = st
        end
        rec["sources"] = srcs
    end
    for (k, v) in extra
        rec[string(k)] = v
    end
    isempty(errors) || (rec["errors"] = errors)

    id = try
        short_sha256(sprint(io -> TOML.print(io, rec; sorted = true)))
    catch err
        push!(errors, "record is not TOML-serializable: " * sprint(showerror, err))
        "unserializable-" * string(time_ns())
    end
    try
        path = joinpath(root, "provenance", id * ".toml")
        if !isfile(path)
            mkpath(dirname(path))
            open(io -> TOML.print(io, merge(rec, Dict("first_captured" => string(now()))); sorted = true),
                 path, "w")
        end
    catch err
        push!(errors, "could not write provenance record: " * sprint(showerror, err))
    end
    isempty(errors) ||
        @warn "Provenance is incomplete (recorded, not fatal):\n  " * join(errors, "\n  ")
    return Provenance(id, String(root), rec)
end

"""
    stamp(path, prov::Provenance; tier, wall_seconds = nothing, extra...)

Write `<path>.prov.toml`, linking the result unit at `path` to `prov` and
recording its tier and cost. Call after the result is completely written.
Any additional keyword arguments are recorded as well.
"""
function stamp(path::AbstractString, prov::Provenance; tier, wall_seconds = nothing, extra...)
    try
        d = Dict{String,Any}("provenance" => prov.id, "tier" => string(tier),
                             "written" => string(now()))
        wall_seconds === nothing || (d["wall_seconds"] = wall_seconds)
        for (k, v) in extra
            d[string(k)] = v
        end
        tmp = path * ".prov.toml.tmp"
        open(io -> TOML.print(io, d; sorted = true), tmp, "w")
        mv(tmp, path * ".prov.toml"; force = true)
    catch err
        @warn "Could not stamp provenance for $path (result kept)" exception = err
    end
    return nothing
end

end # module
