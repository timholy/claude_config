---
description: Profile Julia code to find performance bottlenecks — CPU hot spots, runtime dispatch, GC pressure, allocations, and type instabilities — using a fully headless (no-GUI) workflow
model: Opus
effort: medium
---

Profile a piece of Julia code to locate performance bottlenecks, then report findings and propose optimizations. This skill is the agent-oriented equivalent of the human workflow "run → profile → visualize in ProfileView → click frames." Because an agent cannot use a GUI, this skill works entirely from the *data structures* underneath those GUIs, which are fully scriptable.

This skill *analyzes* and *reports*. It does not silently rewrite code: propose optimizations and get the user's agreement before changing anything, consistent with a fail-fast, human-in-the-loop stance.

The target to profile (a function call, a script, a test) comes from the user. If it is unclear, ask for a concrete entry point and representative arguments.

---

## Setup

Use the **MCP Julia server** (`mcp__julia__julia_eval`), not `julia` via Bash — a persistent session keeps compiled code and profile buffers alive between calls and lets Revise amortize compilation. Use one session for the whole analysis.

Activate the project that owns the code being profiled as `env_path`, so the target loads. That is usually a package's `Project.toml`, but it may equally be a data-analysis project's `Project.toml` that weaves together many packages — the guidance is the same either way. The profiling/measurement packages are developer tools and must **not** be added to the active project's `Project.toml`, whichever kind it is; they resolve from the stacked default environment (`@v#.#`), the same place Revise lives. Needed: `Profile` (stdlib, always available), `FlameGraphs`, `BenchmarkTools`. Optional: `Cthulhu`. If `using FlameGraphs` or `using BenchmarkTools` fails, add them to the default environment:

```julia
using Pkg; Pkg.activate(); Pkg.add(["FlameGraphs", "BenchmarkTools"])
```

then re-activate the project being profiled. **Do not use ProfileView** — it is a pure Gtk GUI with no headless/scriptable output; everything it shows comes from FlameGraphs, which this skill uses directly. No virtual display (Xvfb) is needed.

---

## Step 1 — Warm up

Run the target once, by itself, before measuring anything. The first run pays Julia's JIT-compilation cost; profiling or benchmarking that run measures the compiler, not the code. Discard this result.

---

## Step 2 — Establish a baseline measurement

Benchmark the target with BenchmarkTools so later changes can be judged against a number, not a vibe.

- **Interpolate every external value with `$`.** `@benchmark f(x)` measures global-variable lookup and may let LLVM hoist the computation; `@benchmark f($x)` measures `f`. This is the single most common benchmarking mistake.
- Use `@benchmark` (returns a `Trial`), not `@btime` (prints text and returns the *expression value* — useless to capture programmatically).
- Read results from the `Trial` with the accessors, e.g. `minimum(t)`, `median(t)`; then `time(...)` (nanoseconds), `memory(...)` (bytes), `allocs(...)`, `gctime(...)`.

```julia
using BenchmarkTools
t = @benchmark myfunc($arg1, $arg2)
(; t_ns = time(median(t)), bytes = memory(minimum(t)), allocs = allocs(minimum(t)),
   gc_frac = gctime(median(t)) / time(median(t)))
```

For a **long-running** target (seconds to minutes), `@benchmark` is the wrong tool — it still warms up, tunes, then samples, running the target two or three times, only to end with a single usable sample once the 5-second default budget is blown. Use Base's `@time` / `@timed` / `@elapsed` for a one-shot baseline instead; statistical sampling buys nothing when you can afford only one run. `@timed` returns a `NamedTuple` with `time`, `bytes`, `gctime` — read those fields directly.

Note whether GC time is a meaningful fraction of total — if so, Step 4 (allocations) is where the win is. Note whether the code is fast (sub-millisecond) or slow; this decides how Step 3 collects samples.

---

## Step 3 — CPU profile: find hot spots, runtime dispatch, GC

Collect a sampled CPU profile, then build a FlameGraphs tree from it. The tree is fully traversable data — no rendering, no GUI.

**Collecting samples.** For **fast** code (sub-millisecond), one run yields too few samples; use `@bprofile` from BenchmarkTools, which runs the code many times under the profiler with GC-trial/GC-sample disabled so the signal is clean. For **slow** code (seconds or more), a plain `Profile.@profile` of a single run is enough.

```julia
using Profile, BenchmarkTools, FlameGraphs

Profile.clear()                        # clears the buffer; @bprofile also does this itself
@bprofile myfunc($arg1, $arg2)        # fast code
# Profile.@profile myfunc(arg1, arg2) # slow code — one run

g = flamegraph()                       # builds the tree from Profile.fetch()
```

**The sample buffer accumulates.** `Profile.@profile` *appends* samples to a global buffer; samples from earlier runs stay until `Profile.clear()` is called. So always `Profile.clear()` before a `@profile` run you intend to analyze on its own — forgetting it silently mixes stale data into the profile, a real papercut. The flip side is an opportunity: deliberately *not* clearing lets you profile several different call paths and analyze them as one combined flame graph. `@bprofile` differs — it calls `Profile.clear()` for you, so it always starts fresh and cannot be used to accumulate across calls.

**The buffer has a fixed size.** Profile samples land in a fixed-capacity buffer; once full, sampling silently stops and `Profile.fetch()` / `flamegraph()` warn that the profile is truncated. The default sampling interval is platform-dependent (often ~1 ms) — call `Profile.init()` with no arguments to read back the current `(n, delay)` rather than assuming. At a fine interval like that, a job running for many seconds — let alone minutes — overflows the buffer long before it finishes. Before profiling a long job, coarsen the interval and/or enlarge the buffer with `Profile.init`:

```julia
Profile.init(; delay = 0.01)                   # sample every 10 ms instead of ~1 ms
# Profile.init(; delay = 0.05, n = 10_000_000) # longer still: coarser + bigger buffer
```

The buffer overflows only when the data collected — roughly `(run time / delay) × mean backtrace size` — exceeds its capacity, so a short job at the default fine `delay` usually fits the default buffer and needs no `Profile.init` at all. When a job *does* overflow, which knob to turn depends on its length: for a genuinely long run (roughly 20 s or more), coarsen `delay` — even a coarse interval yields plenty of samples at that length, and fine resolution buys nothing. For a shorter job that still overflows (deep backtraces), coarsening would discard samples you need for statistical confidence, so keep the fine `delay` and raise `n` (the buffer slot count) instead.

**Reading the tree.** `flamegraph()` returns the root `Node`. Each node carries `node.data`, with three fields that matter:

- `node.data.sf` — a `StackFrame`: `.func`, `.file`, `.line`, `.from_c`, `.inlined`.
- `node.data.span` — a `UnitRange`; `length(span)` is the sample count at that node, i.e. its **cost**.
- `node.data.status` — a `UInt8` bitfield. This is exactly the per-frame classification a human reads by hovering/clicking in ProfileView, but as data. Test it against the (non-exported) flags:
  - `FlameGraphs.runtime_dispatch` (`0x01`) — a runtime/dynamic dispatch happened in or below this frame. **The prime optimization target.**
  - `FlameGraphs.gc_event` (`0x02`) — garbage collection happened in or below this frame.

Iterate children with `for child in node`. Flatten the tree and rank:

```julia
function flatten_fg(node, rows = Vector{Any}())
    total = length(node.data.span)
    childtotal = 0
    for c in node
        childtotal += length(c.data.span)
        flatten_fg(c, rows)
    end
    push!(rows, (; sf = node.data.sf, total, self = total - childtotal,
                   status = node.data.status))
    return rows
end

rows = flatten_fg(g)
sort!(rows, by = r -> -r.self)                                              # hottest by self-cost
dispatch = filter(r -> r.status & FlameGraphs.runtime_dispatch != 0, rows)  # dispatch sites
gc       = filter(r -> r.status & FlameGraphs.gc_event != 0, rows)          # GC sites
```

The same function appears as many nodes (one per call path); for a per-function summary, aggregate `self`/`total` by `(sf.func, sf.file, sf.line)`. Report the costliest self-time frames and, separately, the costliest runtime-dispatch frames — the latter are usually where a type-stability fix yields a large speedup.

---

## Step 4 — Allocation profile

If Step 2 showed non-trivial GC time or allocations, profile allocations directly. This is the most agent-friendly tool in the set: `Profile.Allocs.fetch()` returns a plain `Vector` of structs, immediately sortable and groupable — no tree, no decoding.

```julia
using Profile

Profile.Allocs.clear()
Profile.Allocs.@profile sample_rate=0.1 myfunc(arg1, arg2)
allocs = Profile.Allocs.fetch().allocs   # Vector{Profile.Allocs.Alloc}
```

`sample_rate` is the fraction of allocations recorded: `1.0` captures everything (accurate, slow), `0.1` is a reasonable default, `0.01` for long runs. With `sample_rate < 1` counts are estimates, not exact.

Each `Alloc` has `.type` (the allocated object's type), `.size` (bytes), `.stacktrace` (a `Vector{StackFrame}`, leaf first), `.task`, `.timestamp`. Aggregate:

```julia
bytes_by_type = Dict{Any,Int}()
bytes_by_site = Dict{Any,Int}()
for a in allocs
    bytes_by_type[a.type] = get(bytes_by_type, a.type, 0) + a.size
    isempty(a.stacktrace) && continue
    f = a.stacktrace[1]
    bytes_by_site[f] = get(bytes_by_site, f, 0) + a.size
end
sort(collect(bytes_by_type), by = last, rev = true)   # which types dominate
sort(collect(bytes_by_site), by = last, rev = true)   # which call sites dominate
```

**Version caveat:** complete allocation-type capture landed in Julia 1.11. On the LTS (`julia`, 1.10) some allocations come back as `Profile.Allocs.UnknownType` — expected, not a bug. For allocation work, prefer the current release (`julia +1`). The `CorruptType`/`BufferType` sentinels are genuine edge cases on all versions; filter them out if they obscure the picture.

---

## Step 5 — Drill into type instabilities

For the costliest runtime-dispatch frames from Step 3, inspect type inference of the offending function:

- Quick binary check: `using Test; @inferred f(args...)` throws if the return type is not concrete.
- Detailed view: `@code_warntype f(args...)` with representative arguments. In the captured text, look for `::Any`, `::Union{...}`, and `Core.Box` — these mark the unstable variables and return values. `Core.Box` specifically signals a closure capturing a variable that is reassigned.
- These Base/InteractiveUtils tools are stable across Julia 1.10–1.12 and need no setup; prefer them.

`Cthulhu` offers recursive descent through callsites and an unexported programmatic API (`lookup`, `find_callsites`, `RTCallInfo`, `get_rt`/`get_effects`), but it is tied tightly to `Base.Compiler` internals and is version-fragile — its `@descend` TUI is also not agent-drivable. Reach for it only when recursive callsite analysis is genuinely needed and the Julia version is known; otherwise the Base tools above are sufficient. To follow a chain manually, run `@code_warntype` on the unstable callee identified in the previous level.

---

## Step 6 — Report and propose

Summarize for the user:

- Baseline numbers (time, allocations, GC fraction).
- The top CPU self-cost frames, with `file:line`.
- The top runtime-dispatch frames and the type instabilities found behind them.
- The top allocation types and sites.
- Concrete, prioritized optimization proposals — type annotations to stabilize inference, allocations to hoist or eliminate, dispatch to make static — each tied to the evidence above and an estimate of which is likely the biggest win.

Get the user's agreement before editing code. After a change, re-run Steps 1–2 in the same session (Revise picks up the edit) and use `judge(median(after), median(before))` from BenchmarkTools to confirm the change is a real improvement and not noise.

---

## Notes on the tooling

- **ProfileView** is GUI-only and useless headless — skip it; this skill uses its data layer (FlameGraphs) directly.
- **`Profile.fetch()`** returns a raw `Vector{UInt64}` instruction-pointer buffer; do not try to read it directly. `flamegraph()` (Step 3) is the readable form. `Profile.retrieve()` gives the `(data, lidict)` pair if another tool needs it.
- **`@profile_walltime`** (Julia 1.12+) samples blocked/sleeping tasks too — use it instead of `@profile` for I/O-bound or `@spawn`-heavy code, where the ordinary CPU profiler under-counts time spent waiting.
- An agent's edge over the human workflow: instead of eyeballing a flame graph, exhaustively traverse the tree and *aggregate* — total cost per function, ranked dispatch sites, bytes per allocation type. Lean into that.
