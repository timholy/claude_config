module ClaudeUtils

using JSON

export audit_docstrings, search_project

include("audit_docstrings.jl")
include("search_user_comments.jl")   # although this is really intended for bash-shell usage

end # module ClaudeUtils
