This repository holds my personal configuration for agentic coding. Unless you are a scientist or Julia user, it may not be relevant for you.

I'm making it public for the benefit of people in my laboratory and any other users who might want to learn from it. However, it is not intended to be a common resource, and issues/pull requests may be ignored. However, you are welcome to copy or fork this as you see fit (see LICENSE.md).

For me, this repo is my `~/.claude` folder with a lot of required material `git-ignore`d; if you want to use tools from here, either copy the useful bits into your own `~/.claude` or rename your existing `~/.claude` to a temporary name, clone your fork of this repo as your `~/.claude`, and then manually copy all the missing pieces from your old renamed folder.

## Key components

- **CLAUDE.md**: general instructions applicable in every session. Includes stance, programming language and style choices, MCP-agent debugging tips, and devops tips (commits, GitHub etiquette). If you use this, customize it extensively to your own preferences.

- a collection of [skills](https://claude.com/docs/skills/overview) in [commands/](commands)

- a few code fragments in [julia-code/](julia-code) and [subagents](https://code.claude.com/docs/en/sub-agents) (in [agents](agents)) that harvest data used by the main agent

### Skills/commands

#### Tools for doing science

- `/new-analysis-plan` and `/new-analysis-implement`: think of these as "Plan mode for long-running projects" (days, weeks, months). These break up a large project into chunks, maintaining state across chunks through an explicit handoff file format.
- `/write-methods`: while this can be used to generate the methods section for a paper, its primary purpose is to help the user understand the details of an analysis performed during a live session by the agent. Usage example: `> /write-methods, focusing on the analysis involving three categories, ...` Installing [pandoc](https://pandoc.org/) and one or more backends (e.g., Word, LaTeX, etc.) is highly recommended. 

#### Tools for coding and package maintenance

These are targeted at Julia package development; if you're not a Julia user, they are either of no value or should only be used as inspiration.

Required packages (installed in your *global* environment):
- [Revise](https://github.com/timholy/Revise.jl)
- [TestEnv](https://github.com/JuliaTesting/TestEnv.jl)
- [BenchmarkTools](https://github.com/JuliaCI/BenchmarkTools.jl) and [Flamegraphs](https://github.com/timholy/FlameGraphs.jl) if you use the `/profile-performance` skill

Interactive tools:

- `/profile-performance`: teach an agent in the running session the finer points of performance analysis

Focused maintenance tools:

- `/fix-issue`: resolve an issue reported on the issue-tracker
- `/update-compat`: used when a dependency releases a new breaking version
- `/freshen-docstrings`: polish the "docstrings" for methods, types, and constants in a package
- `/freshen-docs`: polish the README and/or [Documenter](https://documenter.juliadocs.org/stable/) documentation
- `/freshen-coverage`: improve [test-coverage](https://en.wikipedia.org/wiki/Code_coverage)
- `/freshen-aqua`: add [Aqua](https://github.com/JuliaTesting/Aqua.jl) tests to a package (enforce certain mechanical aspects of "engineering quality")
- `/freshen-explicit-imports`: add [ExplicitImports](https://github.com/JuliaTesting/ExplicitImports.jl) as a test-dependency (more "engineering quality")
- `/freshen-runic`: use [Runic](https://github.com/fredrikekre/Runic.jl) for auto-formatting without borking your `git-blame`
- `/freshen-gitignore`: add missing common items to the `.gitignore`
- `/limit-struct-mutability`: make `mutable struct`s immutable or add `const` annotations to specific fields

Code review: I have *three* separate reviewing agents, plus a common `/review-implement` for carrying out the agreed changes in a series of chunks (much like the "Tools for doing science" above). Here are the different reviewing agents:

- `/review-design`: review the conceptual design of a package: its scope and identity, level of abstraction, and composability. Scales to large packages because it uses a subagent to extract the essentials of the source code.
- `/review-api`: aligns the package API to the [Julia style guide](https://docs.julialang.org/en/v1/manual/style-guide/). Scales to large packages because it uses a subagent to extract the essentials of the source code.
- `/review-integration`: detailed source-level review of the entire package, including tests and documentation. Only for packages small enough to be read in their entirety without filling the context window.

If I'm modernizing a package, I will typically run *all three* of these agents sequentially, implementing the changes for each before conducting the next review. I typically use the order in which they are described above. This tends to do easy/important cleanup early so that later review steps focus on polishing a package whose main components are well-shaped.

One overall orchestrator:
- `/freshen-package`: runs the whole gamut, in a sensible order

This repository has evolved many times since inception and is likely to undergo continuous evolution.
