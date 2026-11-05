---
name: manuscript-benchmarks
disable-model-invocation: true
argument-hint: "[design | build | rerun | status] [context]"
description: "Design, build, and rerun the benchmark suite behind a manuscript that introduces a new computational method: choose comparisons and ablations that expose the method's core ideas, record provenance without ever blocking a run, keep a cheap tier beside the full one, and draw figures that present the results transparently. Assumes the benchmarks will be rerun many times as the method changes."
---

# Benchmarks for a methods manuscript

## The premise: benchmarks are rerun many times

A benchmark suite for a methods paper is not run once before submission. Expect
a dozen or more full runs and many more partial ones. Each run exposes a
weakness in the method or its implementation. The weakness gets investigated,
the code or the idea changes, and the suite runs again. Some runs fail for
reasons that have nothing to do with the method: harness bugs, out-of-memory
kills, a host that went to sleep.

Nobody can tell in advance which run will be the one that goes into the
submitted manuscript. That depends on whether the outcome meets the author's
standard, and the author decides that after seeing it. So no run gets special
treatment in advance, and no code is allowed to refuse to run because a run
*might* be the final one.

Judge every design decision by its cost on the next rerun and the tenth one: how
long the run takes, what breaks, and how much manual reconciliation it needs
afterward. In earlier projects, most of the cost came from these:

- Provenance checks refused to run because of a dirty tree, a `dev`ed package, a
  fingerprint mismatch, or a stale cache tag. Each refusal led to an escape
  hatch: `--baseline=WHY` flags, hand-edited fingerprints, empty commits made
  only to make the metadata look "clean". Partial reruns were justified by hand
  in commit messages.
- Provenance was recorded once per results directory. The record became wrong
  as soon as part of that directory was recomputed at a newer commit.
- Numbers were typed into the manuscript by hand. After every rerun they had to
  be reconciled line by line, and some stale ones were missed.
- Figure scripts hard-coded population counts, run tags, file names that
  included the tag, or an outcome-dependent selection such as "a representative
  replicate". They broke whenever the population grew, and on cheap runs.
- Full runs took a day to three days, with no cheaper tier that exercised the
  same design. A single pathological instance (81 h) went unnoticed until it
  stalled a run.
- Cheap-tier logic was spread through every stage as `if smoke` branches, so
  adding a tier meant editing every stage.

## Two kinds of signal: fail on correctness, record bookkeeping

Fail fast on anything that means the numbers could be wrong. Record and report
anything that only concerns *where the numbers came from*. Keep the two separate:
turning a bookkeeping signal into an error is what produced every escape hatch
listed above.

| Fail loudly (correctness) | Record and report, never throw (bookkeeping) |
| --- | --- |
| NaN or Inf where the method cannot produce one | a dirty working tree |
| a result that violates the method's own contract (an infeasible step, an increase where descent is guaranteed) | a `dev`ed, unregistered, or unpinned package |
| a method with no entry in the figure style table | results from several commits in one directory |
| an unknown tier name (a typo must not silently run the full tier) | cheap-tier results |
| a results file with the wrong schema | missing units in a partial run |
| a reference value contradicted by a method's result | a provenance field that could not be determined |
| a refit that fails to reproduce a stored result within tolerance | a busy machine during a timing measurement (record the load, flag the row) |

When a method fails on a problem, that failure is data, not an error. Record it
as a row with a status and a message. If a case can't be run (the method doesn't
apply, or a dependency is missing), record it as "skipped", which is distinct
from "error". Either way the denominators stay fixed.

## Choosing a mode

Work out the mode from the arguments and the state of the repository:

- **design**: no benchmark suite exists yet, or the paper's claims have changed.
  See Part 1.
- **build**: a design exists and the harness doesn't, or the harness is missing
  pieces from Part 2.
- **rerun**: code changed and some or all benchmarks need to run again. See
  Part 3. This is the most common mode.
- **status**: report completeness, staleness, and provenance for one or more
  result directories, then stop.

When an existing harness falls short of Part 2 in a way that costs the user
time, say so and propose the change. Don't rewrite a working harness
unprompted, because the user may be in the middle of a run.

## Part 1: Choosing what to benchmark

The detailed guidance is in `references/design.md`. Read it before proposing a
design. The essentials:

1. **Start from the claims.** List each claim the paper will make, for example:
   "on badly scaled problems, method M reaches the target in fewer gradient
   evaluations than L-BFGS, because of idea I." Each benchmark exists to test
   one or more claims. A benchmark that tests no claim is a candidate for
   removal.
2. **Isolate the core ideas.** For each idea that distinguishes the method, add
   an ablation that removes or replaces that idea alone and holds everything
   else fixed. Where possible, graft the idea onto a competing method as well.
   The differences between methods should be traceable to ideas, not only to
   implementations.
3. **Compare against the strongest relevant methods, fairly.** Use the methods
   practitioners actually use, with their authors' implementations. Run them at
   their documented defaults, or tune them with the same budget the new method
   gets. Record every deviation from a default, with the reason. Audit the
   competitors too: baselines have bugs.
4. **Fix the population before looking at results.** Use established test sets
   where they exist, plus constructed problems that isolate a mechanism. Choose
   strata (scale, conditioning, size, noise) so the figures can show *where*
   each method wins and loses. List every exclusion with its reason.
5. **Use metrics that don't favor any method.** Use a common finish line
   adjudicated independently of the methods being compared. Measure cost in
   units that don't depend on the machine (evaluations, gradient equivalents,
   matrix-vector products). Measure wall time separately.
6. **Record expectations before each new benchmark.** After the run, compare
   them with the outcome. Surprises are the most valuable thing a benchmark run
   produces; see Part 3.
7. **Give each figure one takeaway**, written down before the figure is drawn.

Interview the user. `references/design.md` lists the questions. Write the
design to `BENCHMARKS.md` beside the manuscript, as a table of claim,
benchmark, comparison, ablation, and the figure's takeaway, followed by the
population, metrics, and tiers. The file belongs to the current design, so
revise it in place as the design changes. Ask the user whether to commit it or
`.git/info/exclude` it. Their policy for manuscript repositories varies.

## Part 2: Infrastructure built for reruns

### Layout (Julia)

```
benchmarks/
  Project.toml, Manifest.toml  # commit both; the manifest is provenance
  lib/                         # problems, methods, metrics, tiers, storage, provenance.jl
  run.jl                       # julia --project run.jl <tier> [--only=...] [--force] [--root=DIR]
  status.jl                    # completeness + cost + provenance report; never blocks
  compare.jl                   # what changed between two result roots
  figures/                     # style.jl, one script per figure, macros.jl
  publish.jl                   # copy figures, tables, macros from a root into the manuscript
```

Results go in a root *outside* the source paths, with one root per tier and
tag: `<results>/<tier>/<tag>/{raw,derived,figures,provenance}`. Large raw
output belongs on local disk, outside cloud-synced folders. OneDrive
placeholders can stall reads for minutes. Keep old roots rather than
overwriting them, so any two runs can be compared. Name the root that figures
and `publish.jl` use by default in exactly one place, the config. Never put it
in figure file names.

Small or simple suites don't need all of this. Scale the structure to the
project, but keep the properties: resumable units, a provenance sidecar for each
unit, tiers defined as data, and figure scripts that read only derived tables.

### Units of work

- **Choose a unit** that is cheap enough to lose and redo: one (benchmark,
  problem, method, replicate) or one small group. Write each unit atomically
  (write a temporary file, then rename it), so a unit that exists is complete.
  Resuming then means skipping units that already exist. `--force` recomputes
  them, and `--only` filters by benchmark, method, or problem.
- **Reuse by default.** An existing unit is kept even if code has changed since
  it was written. The status report shows which units are stale, and the user
  decides what to recompute. Don't hash the whole code base into a fingerprint
  that invalidates a run. One fix to a figure script once invalidated a
  multi-day run that way.
- **Derive seeds from unit identity**, for example
  `hash((master_seed, benchmark, problem, replicate))`. Any unit can then be
  recomputed on its own, and every method sees the same random instance, which
  makes the comparisons paired.
- **Store long-format tables**, with one row per unit and outcome, including a
  status and a message. When new columns are added, readers must still accept
  older rows that lack them.
- **Record wall time for every unit.** These timings are what make it possible
  to choose a cheap tier, predict run length, and find the pathological
  instance early.
- **Pin method parameters explicitly in the harness** rather than relying on
  package defaults. When a package default changes, the old benchmark arms stay
  reproducible, and adopting the new default becomes a visible change to the
  harness.
- **Key caches of expensive reference computations by content.** Use a hash of
  the inputs that determine the cached value. A key that doesn't match is a
  cache miss, so the value is recomputed; it is not an error. Leave the package
  under test out of the key unless the cached value depends on it.
- **Separate raw from derived results.** Raw output is append-only. An
  aggregation stage reads it and writes derived tables, which are cheap to
  regenerate. Keep slow steps that are only probes in their own stages, so
  re-aggregating stays fast.

### Provenance: record everything, block nothing

Copy `assets/provenance.jl` into the harness (for example as
`lib/provenance.jl`). Copy `assets/provenance_report.jl` beside it, or call it
from `status.jl`. Call `capture` once per process and `stamp` after writing each
unit:

```julia
include("lib/provenance.jl"); using .BenchProvenance
const PROV = capture(root; sources = [joinpath(@__DIR__, "lib"), @__FILE__],
                     extra = Dict("tier" => tier_name))
# ... write unit to `path` ...
stamp(path, PROV; tier = tier_name, wall_seconds = t)
```

The record holds:
- Julia version, host, CPU model, threads, and BLAS configuration. BLAS kernels
  differ by CPU, so results can differ bit for bit between machines.
- The full manifest, stored by content hash.
- Version and tree hash of each direct dependency.
- For each `dev`ed package, its commit, branch, dirty flag, untracked files, and
  the diff of any uncommitted changes. The manifest records only a path for
  these, so their revision must be read from the working tree.
- For the harness sources, the same git information plus a content hash of each
  file.

Records are content-addressed in `<root>/provenance/`. Each unit has a
`<file>.prov.toml` sidecar naming its record, so a directory built up across
many commits stays self-describing. Reusing units in another root means copying
the units with their sidecars, plus the `provenance/` directory. Content
addressing makes merging these directories safe.

What the record must never do:

- **Never stop a run.** No `--require-clean`, no throwing on a dirty or `dev`ed
  package, no `[sources]` pins with checks that error, no refusal to resume,
  publish, or plot. `capture` and `stamp` record "unknown" and warn when they
  can't determine something.
- **Never dirty itself.** Results live outside the source paths. Otherwise a run
  makes its own tree dirty, and someone eventually makes empty commits to tidy
  the metadata. If outputs have to be committed (derived tables, figures), keep
  them out of the `sources` that are passed to `capture`.
- **Never reach the manuscript build.** No commit hash in the TeX and no
  build-time check. A replication README can cite commits, but write it only
  when the user asks.

The submission decision belongs to the user. When the user says a run might be
submission-worthy, run the report:

```
julia --project lib/provenance_report.jl <root> > provenance_report.md
```

Then walk through it with the user: mixed commits, dirty units, files that have
changed since they were used, cheap-tier units, and gaps. Offer to rerun
whatever is stale. Don't decide on your own that a run is final, and don't add a
gate in anticipation of one.

### Tiers: keep the loop short

If the full suite takes more than about two hours, define a cheap tier. Aim for
a cheap tier that runs in minutes, at most about 30, so it can follow every
substantive change. The full tier should ideally fit overnight. An intermediate
tier is worth having when the gap between the two is large.

- **Define tiers as data, in one table.** For each benchmark, the table gives
  the problem subset, sizes, replicate counts, and budgets for each tier. Stages
  read their parameters from the table and never test the tier's name. Adding a
  tier means adding one entry. An unknown tier name is an error.
- **The design is the same; only the size changes.** Use the same methods,
  metrics, code paths, and output schema. A cheap run exists to exercise
  everything a full run exercises.
- **Choose the cheap subset deliberately and list it by name.** It should cover
  every stratum a figure groups or panels by, so no panel is empty. It should
  include the problems that discriminate between methods: known hard cases,
  known failures, and cases the core ideas are meant to help. Use recorded
  `wall_seconds` to fit it within budget, and write down the reasons for the
  choice next to the list.
- **Use the cheap tier as a harness test.** After any harness change, run the
  cheap tier before the full one. Cheap runs find leaks, loops, and schema bugs
  at the cost of minutes.
- **Bound every unit.** A per-unit time or evaluation limit produces a censored
  row ("time limit") instead of a stalled run. The status report lists the
  costliest units, so the user can see a pathological instance early and decide
  whether to cap it, reformulate it, or drop it with a stated reason.
- **Mark the tier in every output:** in the sidecars, in the root path, and as a
  small visible label on any cheap-tier figure.

### Figures and the numbers in the text

The details are in `references/figures.md`, which covers style tables,
physical size, and which displays answer which question. Read it before writing
any figure script. The rules that make figures survive reruns:

- **Figures read only derived tables.** Plotting never computes or measures.
- **Each figure script takes the root as an argument.** It derives panels,
  populations, counts, selections, and axis limits from the data. It contains no
  hard-coded counts and no run tags.
- **Draw what exists.** For a partial or cheap root, print a short completeness
  summary for each figure (units expected and units present). Label any panel
  whose selection came out empty, and keep going. Incompleteness is reported,
  never thrown. Correctness checks, such as an unknown method or an impossible
  value, still throw.
- **Generate the numbers in the prose.** `figures/macros.jl` writes a file of
  `\newcommand` definitions from the derived tables. The manuscript `\input`s a
  committed copy, so the build never needs to run anything. A rerun then changes
  numbers in the text by regenerating that file, with no transcription.
- **Publishing is a copy, not a gate.** `publish.jl <root>` copies figures,
  tables, and macros into the manuscript and writes a `SOURCE.toml` recording
  the root, tier, date, and the summary lines of the provenance report.
- **Look at every figure you regenerate.** Render a PNG and view it with the
  Read tool before reporting. Check that legends, labels, and axis ranges make
  sense with the new data.

### Running long jobs

- **Detach the run.** Use `nohup setsid ... &`. Give Julia a pseudo-terminal
  (`script -qec "julia ..." /dev/null > log`) or flush explicitly, because
  output redirected to a file is block-buffered and is lost if the process is
  killed. Check liveness by PID, not with `pgrep -f`.
- **Leave cores free for the user.**
- **Estimate the duration** from earlier `wall_seconds` before launching, and
  tell the user.
- **Keep timing benchmarks separate from accuracy benchmarks.** Run them on a
  quiet machine. Record the load average on each row and flag contaminated rows
  rather than refusing to run.
- **On WSL, the Windows host can go to sleep** during a long run. Ask the user
  before changing power settings, for example with
  `powercfg.exe /change standby-timeout-ac 0`, and restore them afterward.

## Part 3: Each rerun

1. **Establish what changed.** Check commits in the method's packages and the
   harness since the last run, and work out which benchmarks each change can
   affect. Propose a subset to rerun and say what will be reused and why. The
   status report's list of changed files helps.
2. **If the harness changed, run the cheap tier first.**
3. **Run.** Detach the run if it is long.
4. **Report status:** completeness, the costliest units, and a provenance
   summary.
5. **Compare with the previous run** using `compare.jl` on the two roots. For
   each metric and method, show changes larger than their Monte Carlo
   uncertainty, flips in ranking, and new or vanished failures. This comparison
   replaces hand-made documents listing which numbers changed, and it is not a
   gate.
6. **Investigate surprises before changing anything.** Drill down to single
   instances, plot traces, and check whether a competitor or reference value is
   wrong before concluding that the method is. Report the finding to the user
   with evidence. Whether it leads to a change in the method, the harness, or
   the paper's claims is a joint decision.
7. **Regenerate figures and macros, then look at the figures.** List captions
   and prose claims that the new results contradict, citing line numbers.
   Revising prose is a separate session (see `/writing-manuscripts`), so leave
   the prose alone during a benchmark session.
8. **Tell the user** what ran and at which commits, what moved, what is now
   stale, and what surprised you.

Prune as you go. When a benchmark no longer feeds any figure, table, or claim,
propose retiring it.

## Related skills

- `/writing-manuscripts` covers prose about the results, including the rule that
  experiments shouldn't merely confirm a theorem.
- `/polish-manuscripts` includes a figure-styling consistency check across the
  whole manuscript.
- `/profile-performance` helps when a benchmark unit is slow because of the
  harness or the method's implementation.
- `/new-analysis-plan` is for breaking a large benchmark build into sessions.
