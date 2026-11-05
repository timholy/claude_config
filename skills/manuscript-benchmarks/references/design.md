# Choosing benchmarks for a methods manuscript

The point of a benchmark section is to let a skeptical reader see *when* the new
method is better, *by how much*, *at what cost*, and *which of its ideas are
responsible*, including the cases where it is not better. A suite that only
shows the method winning is less persuasive than one that maps where it wins and
where it loses, and it teaches the author less.

## Contents

1. Interview questions
2. From claims to benchmarks
3. Ablations: tracing differences to ideas
4. Competing methods and fairness
5. Oracles and reference values
6. Problem populations
7. Metrics, cost, and uncertainty
8. Failure accounting
9. Expectations, surprises, and what not to do
10. `BENCHMARKS.md` skeleton

## 1. Interview questions

Ask the user before proposing a design. Use what the manuscript draft, the
method's package, and any existing harness already answer, and ask only about
the rest.

- What are the method's core ideas, the two to four things it does differently
  from existing methods? What does each one buy in theory?
- What claims should the paper make, and which are already supported by proofs?
  Experiments should address what the theory can't settle: practical cost,
  tightness of bounds, behavior outside a theorem's hypotheses.
- Which methods would a referee expect to see compared? Which implementations
  are authoritative? Are there methods the user considers weak or inapplicable,
  and why?
- What populations of problems exist (standard suites, generators, real
  datasets)? Which properties does the theory predict should matter?
- What compute is available (workstation cores, a cluster), and how long can a
  full run take before it slows the project down?
- What does the user expect the results to show?

## 2. From claims to benchmarks

Write each claim in a form that can be falsified: a comparison, a population,
a metric, and a reason. For example, "On least-squares problems with badly
scaled residuals, M reaches γ ≤ 1e-6 in fewer Jacobian products than
Levenberg–Marquardt with Moré scaling, because its damping is invariant to
residual scaling."

For each claim, plan:
- the **comparison** that tests it (which methods, which population, which
  metric);
- the **ablation** that attributes the difference to the stated reason;
- the **stratification** that shows where the claim holds and where it fails;
- the **figure**, with its one takeaway sentence.

Mechanism figures, such as a convergence trace on one instance, are useful for
intuition. They don't replace population results: pair each one with the
population-level evidence that the mechanism is typical.

## 3. Ablations: tracing differences to ideas

- **Change one idea at a time.** Remove or replace one core idea and hold every
  other component fixed: the same stopping rule, budget, line search, and
  initialization. If two ideas interact, include the arm with both removed as
  well.
- **Graft where possible.** Transplant the idea into a competing method, for
  example the new scaling inside an established solver. That separates "this
  idea helps" from "this implementation is good."
- **Decompose exactly when the quantity allows it.** Some quantities split into
  factors, such as excess risk into bias, noise, and selection terms, or
  looseness into independent factors. Then report the factors, not only the
  total.
- **Use oracle arms to separate estimation from selection.** An oracle tuned on
  the truth shows how much of a gap comes from choosing parameters and how much
  from the estimator itself.
- **Report ablations that show an idea doesn't matter.** A finding such as "the
  diagonal alone reaches everything the full cover does" is a result. It may
  simplify the method or sharpen the claim.

## 4. Competing methods and fairness

- **Choose the strongest established methods** that practitioners use for this
  problem class. Include one simple baseline (no preconditioning, the plain
  method) to anchor the scale of improvement.
- **Use authoritative implementations.** If a competitor has to be
  reimplemented or wrapped, test the wrapper against the reference on a few
  cases and say in the paper that it is a reimplementation. If the harness has
  to assemble a competitor from parts, consider dropping it instead.
- **Treat defaults and tuning symmetrically.** Either run every method at its
  documented defaults, "as its users would apply it", or tune every method with
  the same budget and the same procedure. Record every deviation from a default
  with its reason, for example a tolerance tightened because the default moved
  the risk by 6–12%.
- **Use the same inputs and the same scoring.** Every method sees the same
  instances (shared seeds) and is scored by the same independent procedure, not
  by its own report of success. If a competitor reports results on a grid or in
  another representation, measure what converting them costs.
- **Audit the competitors.** Baselines have bugs. Earlier projects found a
  dogleg step that could increase the model and an exact trust-region solver
  returning steps 175 times the radius. Check competitors' outputs against their
  own documented contracts. Decide with the user how to handle a defect: fix it
  locally and report the fix, or report it as found.
- **Keep failure modes visible.** If a competitor fails because of its own
  stopping test, a NaN, or an exception, that is a row with a status. It is not
  a reason to drop the problem.

## 5. Oracles and reference values

- **Compute reference values independently of the compared methods** where
  possible: exact solutions, high-precision solves, analytical optima. When the
  reference is "the best any method found", run it with a larger budget than
  the benchmark uses and say so.
- **Cache expensive references by content hash.** They are usually the slowest
  stage, and they rarely depend on the method under test.
- **Use oracles to bound what can be achieved.** Oracle-tuned variants show the
  headroom and keep reported improvements honest.

## 6. Problem populations

- **Prefer established suites** (CUTEst through OptimizationProblems.jl,
  SuiteSparse, standard distribution families, public datasets) over problems
  chosen by the author. A referee can't accuse an established suite of having
  been picked to flatter the method.
- **Add constructed problems that isolate a mechanism,** clearly labeled as
  such: scale-perturbed copies, ill-conditioned families, size ladders, problems
  outside a theorem's hypotheses, adversarial cases built to break the method.
- **Fix the population and exclusions before seeing results.** Write down the
  filter (for example "unconstrained, n ≥ 2, n ∈ {100, 1000}"). List each
  excluded problem by name with its reason. Never drop a problem because the new
  method does badly on it.
- **Label problems found to be wrong; don't drop them.** If a problem turns out
  to be coded differently from its source, label it and report results with and
  without the labeled problems.
- **Stratify.** Choose replicate cells along the properties the theory says
  matter, for example scale perturbations σ ∈ {0, 1, 3, 5}, sizes, and noise
  levels. Then a figure can plot advantage against the property instead of only
  an average.
- **Size the population for the display.** Performance profiles need enough
  instances (roughly 50 or more) to be meaningful. Statistical comparisons need
  enough replicates that the Monte Carlo standard error is small compared with
  the effects being claimed. Check this per cell.

## 7. Metrics, cost, and uncertainty

- **Use a common finish line.** Define success with a criterion computed by the
  harness from the iterates, for example γ = (f − f*)/(f₀ − f*) ≤ θ, not with
  each method's own convergence flag.
- **Measure cost in machine-independent units first:** function, gradient, or
  Jacobian-product evaluations, gradient equivalents, matrix-vector products,
  iterations. They are reproducible across hosts and unaffected by machine load.
  Measure wall time in a separate stage, on a quiet machine, with BLAS threads
  pinned and the load recorded on every row.
- **Report accuracy and cost together.** A method that is cheaper only because
  it stops early should show up as such.
- **Avoid metrics with a built-in advantage.** Don't score methods with the
  new method's own objective unless every method optimizes that objective.
- **Pair the comparisons and quantify uncertainty.** Shared seeds make each
  comparison paired. Report paired ratios or differences with intervals, and the
  Monte Carlo standard error for each cell. Flag cells where the standard error
  is not small relative to the effect.
- **Fix the budgets during a cheap-tier gate.** Iteration, evaluation, and time
  limits are part of the design. Set them from a cheap run, record them, and
  don't adjust them after seeing full results without saying so.

## 8. Failure accounting

- The number of planned units is the denominator. A completeness table lists
  each cell whose realized count differs from the plan, and in a finished run it
  is empty.
- Use status codes: converged, budget exhausted, time limit, error (with the
  message), and skipped (inapplicable). Record a count of failure messages by
  pattern, so systematic failures stand out.
- Failures enter the metric. In a performance profile a failure is infinite
  cost, and in a reach fraction it is a miss. A method that fails often must not
  look good on the subset it solved.

## 9. Expectations, surprises, and what not to do

- **Write down expectations before a new benchmark runs**, one or two sentences
  each in `BENCHMARKS.md`. After the run, compare. A surprise means one of these
  is wrong: the method, the harness, a competitor, a reference, or the theory.
  Finding out which is the main product of the run.
- **Report effects with uncertainty; don't set pass/fail thresholds.**
  Thresholds tend to get moved after the fact. Paired ratios with intervals let
  the reader judge.
- **Don't select arms after the fact.** All planned arms are reported. If an arm
  is dropped, say why in the paper or the supplement.
- **Keep losses visible** in the figures and the text.
- **Keep correctness checks out of the main benchmarks.** Finite-difference
  convergence or verification that a theorem holds belongs in package tests or
  the supplement.
- **Prune.** Retire a benchmark when no figure, table, or claim uses it. Fewer,
  sharper benchmarks rerun faster and read better.

## 10. `BENCHMARKS.md` skeleton

```markdown
# Benchmarks

## Claims
| # | Claim | Benchmark | Comparison | Ablation | Figure: the one takeaway |
|---|-------|-----------|------------|----------|--------------------------|

## Methods
| Arm | Role (new / ablation / competitor / oracle / baseline) | Implementation | Settings and deviations from defaults |

## Population
Source suites, filters, strata, constructed families, exclusions (name and reason).

## Metrics
Finish line, reference values, cost units, uncertainty, budgets.

## Tiers
| Tier | Subset (by name) and why | Sizes, replicates | Expected wall time |

## Expectations
Written before each new benchmark; outcome noted after the run.
```
