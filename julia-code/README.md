# Structure of julia-code

`ClaudeUtils` contains julia functions that are used for code-reconnaisance by (sub)agents. Because Julia has rich introspection for code, we can use Julia functions to extract just the information needed, thus avoiding filling the context window with distracting information.

`search_user_comments.jl` is a shell utility meant to search cached conversations between humans and agents. Usage:

    julia search_user_comments.jl <pattern> [project_glob]

It has supporting source code (with the same filename) in `ClaudeUtils`; the two files are *not* redundant.
