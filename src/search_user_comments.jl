#!/usr/bin/env julia
"""
Search through past user messages across Claude Code project conversation logs.

Usage:
    julia search_user_comments.jl <pattern> [project_glob]

Arguments:
    pattern       Regex pattern to search for (case-insensitive by default)
    project_glob  Optional glob to filter project directories (default: "*")

Examples:
    julia search_user_comments.jl "Revise"
    julia search_user_comments.jl "sparse" "*Revise*"
    julia search_user_comments.jl "(?i)makie" "*Swarm*"
"""

using JSON

const PROJECTS_DIR = expanduser("~/.claude/projects")

function extract_text(content)
    content isa AbstractString && return content
    content isa AbstractVector || return ""
    parts = String[]
    for block in content
        block isa AbstractDict || continue
        get(block, "type", "") == "text" || continue
        push!(parts, get(block, "text", ""))
    end
    return join(parts, "\n")
end

function is_slash_command(content)
    content isa AbstractString || return false
    return startswith(content, "<command-message>") || startswith(content, "<command-name>")
end

function search_project(dir, pattern)
    results = []
    for f in readdir(dir; join=true)
        endswith(f, ".jsonl") || continue
        session_id = basename(f)[1:end-6]
        open(f) do io
            for line in eachline(io)
                isempty(strip(line)) && continue
                obj = JSON.parse(line)
                get(obj, "type", "") == "user" || continue
                # Skip non-human-authored message types
                get(obj, "isCompactSummary", false) == true && continue
                startswith(get(obj, "agentId", ""), "acompact-") && continue
                get(obj, "isMeta", false) == true && continue
                msg = get(obj, "message", nothing)
                msg === nothing && continue
                get(msg, "role", "") == "user" || continue
                content_raw = get(msg, "content", "")
                is_slash_command(content_raw isa AbstractString ? content_raw : "") && continue
                text = extract_text(content_raw)
                isempty(strip(text)) && continue
                occursin(pattern, text) || continue
                push!(results, (
                    timestamp = get(obj, "timestamp", ""),
                    session = session_id,
                    text = text,
                ))
            end
        end
    end
    return results
end

function main(args)
    if isempty(args)
        println(stderr, "Usage: julia search_user_comments.jl <pattern> [project_glob]")
        exit(1)
    end
    raw_pattern = args[1]
    project_glob = length(args) >= 2 ? args[2] : "*"

    # Default to case-insensitive unless the pattern already has a flag
    pattern = startswith(raw_pattern, "(?") ? Regex(raw_pattern) : Regex(raw_pattern, "i")

    project_dirs = filter(isdir, [
        joinpath(PROJECTS_DIR, d)
        for d in readdir(PROJECTS_DIR)
        if project_glob == "*" || occursin(project_glob, d)
    ])

    total = 0
    for dir in sort(project_dirs)
        project_name = basename(dir)
        hits = search_project(dir, pattern)
        isempty(hits) && continue
        println("\n=== $project_name ($(length(hits)) match$(length(hits)==1 ? "" : "es")) ===")
        for h in sort(hits; by=x->x.timestamp)
            ts = h.timestamp[1:min(19,end)]
            session_short = h.session[1:8]
            # Print up to 3 lines of context around each match
            lines = split(h.text, '\n')
            matched_lines = findall(l -> occursin(pattern, l), lines)
            shown = Set{Int}()
            for ml in matched_lines
                for i in max(1,ml-1):min(length(lines),ml+1)
                    push!(shown, i)
                end
            end
            context = join([lines[i] for i in sort(collect(shown))], "\n  ")
            println("  [$ts | $session_short]")
            println("  $context")
        end
        total += length(hits)
    end
    println("\nTotal matches: $total")
end

main(ARGS)
