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

using Pkg
Pkg.activate(joinpath(@__DIR__, "ClaudeUtils"))
using ClaudeUtils

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
        joinpath(ClaudeUtils.PROJECTS_DIR, d)
        for d in readdir(ClaudeUtils.PROJECTS_DIR)
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
