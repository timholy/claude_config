if Base.VERSION >= v"1.11"
    eval(Meta.parse("public PROJECTS_DIR"))
end

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
