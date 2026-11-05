# Figures and numbers for benchmark results

A good benchmark figure lets the reader answer the claim's question at a glance,
and then check it: every instance and every failure is visible, and the
comparison the claim rests on is the comparison the eye makes first. Figures
also get regenerated many times, so they must work for any root, any tier, and
any partial run without edits.

## Contents

1. Plan the figure before drawing it
2. Structure: data, style, layout
3. A shared style table
4. Physical size and type
5. Showing results transparently
6. Which display answers which question
7. Figures that survive reruns and tiers
8. Numbers in the text
9. Checking the result

## 1. Plan the figure before drawing it

Write the one takeaway in `BENCHMARKS.md` before writing the script. For
example: "the scale-invariant arm's advantage grows with σ, and the ablation
without the cover loses it." Then choose the display whose primary visual
comparison is that statement: adjacent bars, a shared axis, or a ratio
reference line. If a figure has no single takeaway, it is probably two figures,
or a table.

## 2. Structure: data, style, layout

Keep three concerns apart:

- **What** is plotted: functions that turn derived tables into plot elements.
  They draw into an axis the caller supplies and never create their own
  figure, so the same function serves a quick diagnostic and a multi-panel
  layout.
- **How** it is styled: one shared style file.
- **Where** it appears: one script per manuscript figure that assembles the
  panels.

Figure scripts read only derived tables. They never run a method, refit, or
measure. If a figure needs a quantity that no derived table holds, add it to the
aggregation stage.

## 3. A shared style table

Each concept (a method, an ablation, a reference) has one entry that every
figure uses: label, color, marker, and line style, listed in legend order. A
method with no entry is an error, not a fallback color. A silent default color
lets two methods look identical.

```julia
const OKABE_ITO = ["#E69F00", "#56B4E9", "#009E73", "#F0E442",
                   "#0072B2", "#D55E00", "#CC79A7", "#000000"]

const STYLES = [   # legend order
    :ours       => (label = "M",               color = OKABE_ITO[5], marker = :circle,  linestyle = :solid),
    :ours_nocov => (label = "M without cover", color = OKABE_ITO[5], marker = :circle,  linestyle = :dot, open = true),
    :lbfgs      => (label = "L-BFGS",          color = OKABE_ITO[6], marker = :utriangle, linestyle = :dash),
]
const STYLE = Dict(STYLES)
style(m) = get(() -> error("no style for method $(repr(m)); add it to STYLES in figures/style.jl"), STYLE, m)
```

Conventions that have worked:
- **Make roles recognizable.** The new method uses solid lines and filled
  markers. Competitors use dashed lines. An ablation or variant shares the hue
  of the method it modifies, with a dotted line or an open marker. Assigning
  color by role (new, ablation, competitor, oracle) rather than by method keeps
  figures readable as arms are added.
- **Make it work in grayscale.** Markers and line styles alone must distinguish
  the methods. The Okabe–Ito palette is safe for color-vision deficiencies.
- **Keep the same order everywhere:** legends, panels, and strata such as
  problem families use one fixed order.
- **Be consistent across companion papers.** When papers share concepts, they
  share glyphs and colors.
- **Draw references the same way everywhere,** for example a thin gray dashed
  line for the truth or for y = x.

## 4. Physical size and type

- **Draw at printed size.** Find the text width from the journal class: compile
  `\showthe\textwidth`, or typeset `\the\textwidth`. TeX points are 1/72.27 in,
  and PDF points are 1/72 in, so a 345 pt `\textwidth` is `345 * 72 / 72.27`
  PDF points. In CairoMakie, `save(path, fig; pt_per_unit = 1)` makes the
  figure `size` count in PDF points.
- **Match the type to the caption.** Use roughly 8 pt for labels and 7 pt for
  ticks in a 10 pt document. Never scale a figure in LaTeX to fit, because that
  changes the type size.
- **No titles inside the figure.** The caption carries the message. Each
  figure script's docstring lists what the caption must state: population,
  tier, metric, and what the markers mean.
- **Output both formats.** Write PDF for the manuscript and PNG (about 4 px per
  pt) for inspection and review pages.

## 5. Showing results transparently

- **Show distributions, not only averages.** Plot per-instance points, paired
  scatter, or profiles. If a summary is necessary, show its spread or interval
  too.
- **Show failures explicitly:** an "∞" marker or a strip beyond the axis, the
  plateau of a performance profile, or a count in the panel. Never let a failed
  instance disappear from a plot.
- **Derive axis limits from the data,** so a value that moves after a rerun
  widens the axis instead of quietly leaving the frame. Don't drop outliers;
  if they compress the plot, use a broken or log axis and say so.
- **Put ratios on log axes, symmetric about 1, with a minimum span** (for
  example at least 0.8–1.25). That way a 2% difference doesn't fill the panel.
- **Share axes across panels that are compared,** and say in the caption when
  they aren't shared.
- **Report n in or under each panel.** For partial or cheap roots, report it
  as present out of planned.
- **Avoid censoring that misleads.** For a lower bound or a capped value, plot
  it with a distinct marker or not at all, and say which.

## 6. Which display answers which question

| Question | Display | Notes |
| --- | --- | --- |
| Over a population, which method reaches the target at the least cost? | Performance profile (Dolan–Moré) or data profile | Needs about 50 or more instances. The profile depends on which methods are included, so keep that set fixed. State the cost unit, and treat failures as infinite cost. |
| How does each instance compare between two methods? | Paired scatter on log–log axes with y = x | Shows every instance. Mark failures on the margins. |
| Where does the method win? | Paired ratio (with interval) against a stratum: σ, n, conditioning | The most direct evidence for "because of idea I" when the stratum is what the idea addresses. |
| Which idea is responsible? | Ablation dot chart, or stacked factors for an exact decomposition | Order the bars or dots by ablation, not by value. |
| What is the trade-off? | Cost against accuracy (Pareto front) | One point per setting, connected within a method. |
| What is the mechanism? | Convergence traces on representative instances | Choose "representative" by a written rule applied to the data, show the spread across instances, and handle an empty selection. |

Tables suit small numbers of exact values that a reader will look up. Figures
suit patterns.

## 7. Figures that survive reruns and tiers

- **Take the root as an argument.** The default comes from the one place the
  config names it. Output file names must not contain the run tag. The
  manuscript includes `figures/profiles.pdf` whichever root produced it.
- **Derive everything from the data:** methods present, problem families,
  sizes, counts, panel layout, and selections. Don't put the expected
  population size in figure code. When a planned-count check is wanted, read the
  plan from the tier table, and report the difference rather than throwing.
- **Print a completeness summary before drawing.** For each panel, report
  planned, present, failed, and missing units. Draw what is present.
- **Handle empty selections.** If a rule picks nothing ("a replicate where the
  adaptive selector moved"), leave the panel empty with a short note, print the
  reason, and continue.
- **Label the cheap tier.** Add a small, unobtrusive "cheap tier" label in a
  corner of every figure drawn from a non-full root, for example
  `Label(fig[0, :], "cheap tier"; halign = :right, fontsize = 6, color = :gray, tellwidth = false)`.
  Then a draft never shows cheap results by mistake.
- **Correctness failures still throw:** an unknown method, an impossible value,
  or a schema mismatch.

## 8. Numbers in the text

Every number in the prose that comes from a benchmark should come from a
generated macro. Hand-transcribed numbers go stale on every rerun, and
reconciling them by hand is slow and error-prone.

```julia
# figures/macros.jl: derived tables -> results_macros.tex
function write_macros(path, macros; source)
    open(path, "w") do io
        println(io, "% Generated by figures/macros.jl from ", source, ". Do not edit.")
        for (name, value) in macros
            occursin(r"^[A-Za-z]+$", name) || error("LaTeX macro names must be letters only: $name")
            println(io, "\\newcommand{\\", name, "}{", value, "}")
        end
    end
end
```

- Format each value where it is defined, with the significant figures the claim
  needs. Don't print more digits than the Monte Carlo error supports.
- Name macros for what they mean, such as `\ReachScaledOurs`, not for where
  they appear.
- The manuscript `\input`s a committed copy in the manuscript directory, which
  `publish.jl` updates. The build never depends on the harness, on provenance,
  or on a results root.
- Numbers that are stated to justify a design choice, such as "the default
  moved risk by 6–12%", come from a derived table as well.

## 9. Checking the result

After every regeneration:

- **View the PNG of each changed figure** with the Read tool. Check legends,
  labels, axis ranges, the cheap-tier label, and anything empty or clipped.
- **Compare the figure with its takeaway sentence.** If the data no longer
  support the takeaway, tell the user. Don't adjust the figure until the
  statement is true again.
- **List captions and prose that mention a style** ("the blue curve") or a
  number not generated as a macro.
- **Run the consistency check across figures** in `/polish-manuscripts` for a
  whole-manuscript pass.
