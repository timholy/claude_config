---
name: new-analysis-plan
description: >
  Use this skill when the user wants to start a new analysis project and has an AGENT_INSTRUCTIONS or
  project description to work from. Triggers only on explicit command `/new-analysis-plan`. This skill
  produces a persistent plan document that drives the companion `/new-analysis-implement` skill.
# Recommended invocation: opus model, /effort high
---

# New Analysis Plan

You are helping a researcher or analyst decompose a new project into a structured,
implementable plan. Your output is a single Markdown plan file that will persist across
context windows and drive the companion implementation skill.

## Step 1: Evaluate the AGENT_INSTRUCTIONS

Before decomposing, assess what the user has given you. A good plan requires:

- **Goal**: What does success look like? What question is being answered?
- **Data**: What inputs exist, in what format, where?
- **Language/environment**: What language and key libraries will be used?
- **Known constraints**: Performance, reproducibility, deadlines, collaborators?

If the user cannot describe the data format, do not block planning — instead,
make CHUNK-001 a dedicated data reconnaissance chunk: open the files, describe
what's there (shape, types, encoding, any obvious quality issues), and write
findings to a short `DATA_NOTES.md`. Mark all downstream data-loading chunks as
depending on CHUNK-001 and flag format as an open question. The implementer will
resolve it in the first session.

For other missing information, ask the user to fill the gaps before proceeding.
Do not attempt decomposition on an underspecified AGENT_INSTRUCTIONS — a plan built on
guesswork will mislead the implementer. Be direct about what's missing.

## Step 2: Establish Project Maturity Target

Ask the user (or infer from context) what kind of artifact this project should produce.
This decision shapes the entire plan — particularly the first substantive chunk.

| Target | Description |
|---|---|
| `script` | A working analysis script or notebook. No package structure required. Appropriate for quick, one-off work or users new to software engineering practices. |
| `package` | A proper package with `src/`, `test/`, and a project/environment file. Reusable, testable, and extensible. Recommended default for any project expected to grow. |
| `releasable-package` | As above, but held to a standard where adding `docs/` and publishing would be realistic. Includes docstrings, a clean public API, and passing tests throughout. |

Record this as `**Project maturity target**` in the plan header. The implementer will
read it and adjust its behavior accordingly.

**If the user is unsure**, briefly explain the tradeoff: scripts are faster to start but
harder to build on; packages take one extra chunk upfront but pay dividends in every chunk
after. Recommend `package` as the default for any project expected to grow beyond a single
session. Do not impose — record whatever the user decides.

**For `package` and `releasable-package` targets**, the first substantive chunk (after any
data reconnaissance) must be `scaffold-package`. See scaffolding guidance below.

Julia-specific point: the Julia ecosystem leans towards smaller,
conceptually-clean packages, and a single new analysis project might result in
more than one new package and/or modifications to multiple existing packages. If
a chunk's functionality seems generically useful beyond this project, consider
whether it warrants its own package. Future steps should take this possibility
into account.

## Step 3: Establish Target Outputs

Before decomposing the project into chunks, sketch with the user what the
project's *final* outputs are expected to look like. These are the figures,
tables, or success criteria that, if produced and correct, would constitute the
project being "done."

**This is a draft, not a contract.** The form of the outputs will almost
certainly shift as understanding accumulates — that is precisely the point of
capturing them now. Crown-jewel chunks (see Step 5) are the moments where this
section is expected to be revised.

For each anticipated output, capture:

- A short name (e.g., "Figure 1: residual histogram by group")
- One or two sentences describing what it shows and what would make it
  satisfying / unsatisfying
- Optional: a rough verbal sketch ("x-axis: time bin; y-axis: count; expect a
  bimodal distribution centered near 0 and 0.7")

Ask the user to provide these or sketch them collaboratively. Do not fabricate
target outputs the user has not articulated or assented to.

**For genuinely exploratory projects** where the form of success is not yet
known, record a single entry `exploratory — to be determined` along with a
brief note on what early chunks should produce to begin shaping the targets.
In this case, plan an early `investigate` chunk whose explicit deliverable is
"propose 1–3 candidate target outputs based on what the data looks like," and
make the eventual integrative chunk depend on it and be marked as a
crown-jewel.

## Step 4: Package Scaffolding Guidance

When the maturity target is `package` or `releasable-package`, include an explicit
`scaffold-package` chunk before any analysis logic is written. Record the expected
structure in its Description field so the implementer knows what to build.

For Julia, Python, and R, first ask the user if they want to create the package
using standard tooling (`PkgTemplates.jl`, `cookiecutter` with
`cookiecutter-scientific-python`, and `usethis`, respectively). For MATLAB, or
if this option is declined, refer to the idioms below.

**Julia** (idiomatic structure):

```
MyProject.jl/
├── Project.toml          # generated by Pkg.generate() or `] generate`
├── src/
│   └── MyProject.jl      # module entry point; exports public API
├── test/
│   └── runtests.jl       # using Test; @testset blocks
└── scripts/              # analysis scripts that `using MyProject`
    └── reproduce_fig1.jl
```
Special case: if extending an existing `dev`'d package, record the package name and
local path. The scaffolding chunk adds new functions to `src/` and tests to `test/`
within that package rather than creating a new one.

**Python** (modern src-layout):
```
myproject/
├── pyproject.toml        # build system + deps; prefer uv or hatch
├── src/
│   └── myproject/
│       └── __init__.py
├── tests/
│   └── test_*.py         # pytest
└── scripts/              # analysis scripts that import myproject
    └── reproduce_fig1.py
```

**R** (package structure):
```
MyProject/
├── DESCRIPTION
├── NAMESPACE
├── R/                    # function definitions
├── tests/
│   └── testthat/         # testthat
└── scripts/              # analysis scripts using library(MyProject)
```

**MATLAB** (toolbox structure):
```
MyProject/
├── +MyProject/           # package namespace
│   └── *.m               # functions
├── tests/
│   └── Test*.m           # matlab.unittest
└── scripts/
    └── reproduce_fig1.m
```

The key principle across all languages: **analysis logic lives in the package (`src/` or
equivalent), analysis scripts live outside it (`scripts/`)**. Scripts are thin — they
import the package, call functions, and produce outputs. They are not where the work lives.

## Step 5: Decompose into Chunks

A chunk is a **single function, module, or self-contained capability** with:
- Clear inputs and outputs
- A definition of done that can be verified
- A realistic scope (implementable in one focused agent session)

**Decomposition rules:**
- Prefer too many small chunks over too few large ones
- Each chunk should be independently testable or verifiable
- Name chunks as verb phrases: `load-and-validate-data`, `fit-baseline-model`, `plot-residuals`
- Identify which chunks depend on others and record this explicitly
- For `package`/`releasable-package` targets: each chunk that adds a function should
  also add the corresponding tests — treat implementation and tests as one unit of work,
  not separate chunks

**Chunk types and typical verification strategies** (the implementer will decide the final
strategy, but flag your expectation here):

| Chunk type | Suggested verification |
|---|---|
| Data reconnaissance | `DATA_NOTES.md` written; manual review |
| Package scaffolding | Package loads cleanly; test runner passes on empty suite |
| Data loading / parsing | Synthetic in-memory fixture with known shape/values; no external files |
| Transformation / cleaning | Invariant assertions on synthetic data (symmetry, invertibility, conservation) |
| Algorithm / model | Unit tests against analytical results or a simple reference implementation |
| Visualization | Manual review (note this explicitly) |
| I/O / export | Round-trip check using a temp file or in-memory buffer; no real data paths |
| Orchestration / pipeline | Integration test over a small synthetic input constructed in the test itself |

**Portability rule for `package`/`releasable-package` targets**: every committed test must
pass on a clean machine with no access to the project's data files or analysis outputs.
Use synthetic fixtures with known ground-truth answers; validate on real data during
development, but record that in session notes rather than the test suite.

**Crown-jewel chunks:**

A small number of chunks (typically 1–3, late and integrative) are *crown jewels*:
chunks whose framing is expected to shift meaningfully once prior chunks have produced
artifacts and the user has built intuition. These are usually the chunks closest to the
project's Target Outputs — the synthesis figure, the headline comparison, the final model
evaluation.

Mark such chunks with `Crown-jewel: yes`. Default is `no`.

The implementer treats `Crown-jewel: yes` as a signal to *re-plan before implementing* —
not as a status. See `/new-analysis-implement` for the behavior. `Crown-jewel` is a flag,
orthogonal to `Status`.

Suggest crown jewels to the user and ask for confirmation; do not assign the flag
unilaterally. When unsure, prefer marking late integrative chunks `yes` rather than `no` —
the cost of a re-plan checkpoint is small, and the benefit of catching a stale framing is
large.

**Snapshot tier (for visual / manual-review chunks):**

For any chunk whose verification is "manual review" or otherwise visual, record a
`Snapshot tier:` field with one of:

| Tier | When to use |
|---|---|
| `none` | No snapshot. Fine for one-off exploratory plots. |
| `data` | **Default for visual chunks.** Snapshot the underlying numbers (arrays, summary statistics) with a tolerance. Robust across rendering backends and font versions. |
| `features` | Snapshot a hash of derived features (quantile sketch, peak locations, top-k indices). Use when raw data snapshots are too large. |
| `image` | Pixel-level image comparison. Reserved for chunks where the visual appearance itself is the deliverable (e.g., publication figure layout). The implementer mediates diffs by loading both images and judging meaningful vs cosmetic. |

Non-visual chunks (algorithmic, I/O, etc.) do not need this field. If the field is
omitted, the implementer treats it as `none` for non-visual chunks and `data` for visual
chunks.

## Step 6: Order the Chunks

Produce a dependency-ordered list. The typical order for a `package`-target project is:

1. Data reconnaissance (if format is unknown)
2. Package scaffolding
3. Data loading / parsing
4. Core logic chunks (in dependency order)
5. Visualization / output chunks
6. Orchestration / end-to-end script

Where the ordering is ambiguous, prefer getting data loading done early — downstream
chunks are much easier to verify when you can run them on real data.

## Step 7: Write the Plan File

Save the plan as `ANALYSIS_PLAN.md` in the project root (or a location the user specifies).

Use exactly this schema so the implementer can parse it reliably:

```markdown
# Analysis Plan
<!-- Auto-generated by /new-analysis-plan. Edit freely, but preserve chunk IDs and status values. -->

## Project Summary
[2–4 sentence summary of the goal, data, and language/environment]

## Language & Environment
- **Language**: [e.g. Python 3.11, Julia 1.10, R 4.3, MATLAB R2024a]
- **Key libraries**: [e.g. pandas, numpy, scipy / Flux.jl / tidyverse / Statistics Toolbox]
- **Environment file**: [e.g. environment.yml, Project.toml, renv.lock — or "none yet"]
- **Project maturity target**: [`script` / `package` / `releasable-package`]
- **Package name(s)**: [e.g. MyProject.jl — or "n/a" for script target]
- **Extending existing package(s)**: [package name + local path, or "no"]

## Target Outputs
<!-- Draft sketches of the project's final figures/tables/success criteria. Expected to be
     revised, especially during crown-jewel re-plans. Use "exploratory — to be determined"
     if the form of success is unknown. -->

- **[Output name]**: [1–2 sentences on what it shows and what would make it satisfying]
- **[Output name]**: ...

## Chunks

### CHUNK-001: [chunk-name]
- **Description**: [What this chunk does]
- **Inputs**: [Files, data structures, or outputs from prior chunks]
- **Outputs**: [Files, data structures, or return values]
- **Depends on**: [CHUNK-XXX, or "none"]
- **Verification strategy**: [Suggested approach — implementer may revise]
- **Snapshot tier**: [none | data | features | image]   <!-- omit or `none` for non-visual chunks -->
- **Crown-jewel**: no
- **Status**: `not-started`
- **Notes**:

### CHUNK-002: [chunk-name]
...

## Decisions
<!-- Captures answers to any chunks where the implementer paused for input, and outcomes
     of crown-jewel re-plans. Each entry: date, what was decided, brief rationale. -->

## Session Log
<!-- The implementer appends an entry here after each session. -->

## Open Questions
<!-- Unresolved ambiguities that may affect implementation. Implementer should surface blockers here. -->
```

## Step 8: Brief the User

After writing the file, tell the user:

1. What the plan covers, how many chunks it contains, and what the maturity target is
2. Flag any open questions — these should be resolved before implementation begins
3. Note any chunks marked `Crown-jewel: yes` and explain that the implementer will pause
   before those chunks for a re-plan checkpoint, not begin coding immediately
4. Explain the workflow: run `/new-analysis-implement` to begin, and repeat that command
   at the start of each new session after `/clear`
5. Remind them that the plan is a living document — they can and should edit it as the
   project evolves

## Important Notes

- Do **not** begin any implementation in this skill. Planning only.
- Do **not** generate package scaffolding or boilerplate code here — that is the
  `scaffold-package` chunk's job. The plan is the deliverable.
- If the AGENT_INSTRUCTIONS describes a project that is already partially implemented,
  mark completed chunks `complete` with a note rather than re-planning from scratch.
- This skill is re-entrant: if called on a project with an existing `ANALYSIS_PLAN.md`,
  read it first and offer to revise rather than overwrite.
