---
name: write-methods
description: >
  Use this skill when the user wants a methods write-up of an analysis project — either a
  consolidated, living account of the whole project or a focused explanation of one stage or
  result. Triggers only on the explicit command `/write-methods`. Its primary purpose is
  human-agent alignment: reconstruct the chain from data to choices to key results, surface the
  challengeable assumptions, and ask the user to confirm the riskiest ones. Companion to
  `/new-analysis-plan` and `/new-analysis-implement`.
# Recommended invocation: opus model, /effort medium
---

# Write Methods

You are producing a **methods document** for an analysis project. A methods section in the
classic sense — a paper-ready account of what was done — is a welcome byproduct, but it is not
the goal. The goal is **human-agent alignment**: this document is the verbal counterpart to the
project's figures. Where a figure exposes the *data and results*, this document exposes the
*chain of choices that produced them*, in a form a busy human can skim and be productively
skeptical about.

Aim for **skepticism, not pessimism**. Agentic analysis produces results that are both
"too good to be true" and "too bad to be true," most often when human and agent understand the
task slightly differently. The recurring failure classes you exist to surface:

- **Data provenance** — *which* data actually fed a conclusion (e.g. computing a statistic over
  a region of an image that does not contain the feature of interest).
- **Model / parametrization** — the specific model and parametrization chosen, vs. the one the
  user meant.
- **Provenance of ingredients** — how the inputs to an analysis came to be (data sources,
  preprocessing, reference values, and especially how ground truth was generated), and how those
  origins limit or shape what the results can validly mean. Misreading what an ingredient *is*
  quietly distorts every interpretation built on it.

Your document must make these inspectable and challengeable. A faultlessly fluent narrative that
hides its load-bearing assumptions is a failure, however well written.

## Step 1: Orient — mode and scope

Read, if present:

1. **`ANALYSIS_PLAN.md`** — especially `Target Outputs` (the figures/views and the result→origin
   intent), `Working knowledge` (corrections accumulated across sessions — these are
   authoritative), per-chunk `Notes` (where decisions and rationale are recorded), and the
   maturity target.
2. **`ANALYSIS_SESSION.md`** — recent handoff decisions and known issues.

These tell you what the project *claims* it did. Treat them as claims to verify, not as truth
(Step 2 explains why).

Then settle two axes with the user (infer if obvious, ask if not):

- **Mode**:
  - **Focused** — explain one stage or one result ("show me where *this* number came from").
    Cheap, targeted, *ephemeral by default*.
  - **Consolidated** — the whole-project narrative as a *living, durable* `METHODS.md`.
- **Scope**: which stage / result / chunk(s), or the whole project.

If there is no `ANALYSIS_PLAN.md`, the skill still works: ask the user to point you at the code
and the result(s) to document, then proceed. The plan simply makes orientation cheaper.

A common case: a single session explores **many flavors of the same analysis**, and only one is
worth documenting. Steer this with the invocation itself — e.g. "`/write-methods`, document only
the variant that uses …" — and honor an explicit selection; if which variant matters is unclear,
ask rather than guess. But note that **selecting one variant from many is itself a load-bearing
choice**: presenting the chosen result as if it were the only analysis run invites a
too-good-to-be-true reading (a garden-of-forking-paths problem). By default, record that other
variants were explored and deliberately excluded — at minimum as a calibration note (Step 3) —
unless the user directs otherwise.

## Step 2: Delegate the investigation to a subagent

The investigation is the expensive part: reading source code, tracing a result back to the data
and parameters that produced it, and checking that against the project's own account. Doing this
in the main session would fill the context window and degrade your later judgment — including the
quality of the alignment conversation in Step 5. **So delegate it.** Launch a subagent, let it do
the heavy reading, and have it return a compact brief. Your context stays clean.

Practice **targeted skepticism**, not exhaustive audit. Spend the subagent's budget only on the
choices that are *load-bearing* for the result(s) in scope — the data subset, the transform and
its parametrization, the ground-truth procedure. Lean on the project's own legibility for
everything else: the ecosystem deliberately builds tightly-focused, transparent atomic units with
decisions recorded in chunk `Notes`, so most of the narrative can be assembled by trusting those
artifacts. Verify against the code only where a wrong answer would actually change a conclusion.

Instruct the subagent to read **the code and data as the source of truth**, the plan/Notes as
claims to check against, and to return — for each key result in scope — a brief of this shape:

```markdown
### Result: [what it is — a number, a figure, a claim]
- **Origin chain**: data subset used → transform/model → parametrization → output
- **Code locations**: file:line for the load-bearing steps
- **Ground-truth handling**: how ground truth was generated/used, if applicable
- **Verified**: which steps were checked against the code (vs. taken from the plan/Notes)
- **Discrepancies**: where the code disagrees with the plan/Notes, or "none found"
- **Risk flags**: assumptions most likely to be misaligned with user intent;
  results that look "too good" or "too bad" to be true
```

If a value or rationale cannot be recovered from the artifacts, the subagent must report it as a
**gap** — never invent a plausible-sounding parameter or justification. Surfacing the gap is
correct behavior; papering over it defeats the purpose.

## Step 3: Draft the methods document

Write the canonical document as **Pandoc-flavored Markdown** (see Step 4 for why Markdown is the
source format). Structure it around results, not around code organization:

1. **Brief overview** — data, goal, environment, in 2–4 sentences.
2. **Per key result: the origin chain** — for each headline result or figure, narrate backward
   from the result to the data subset, transform, model, and parametrization that produced it.
   Reference the actual figures from `Target Outputs` by relative path ("Figure 3
   (`scripts/fig3.png`) was produced by …"), so the verbal and visual channels reinforce rather
   than duplicate.
3. **Assumptions to check** — a *prominent, non-buried* list of the load-bearing choices, each
   phrased as a challengeable statement the user can accept or reject:
   - "Region X of the image was treated as the feature of interest."
   - "The model was parametrized as A rather than B."
   - "Ground truth was assumed to be generated by process P."
   This section is the heart of the document. Order it by the subagent's risk flags.
4. **Calibration notes** — plainly flag any result that looks surprisingly strong or weak, and
   say what would make it untrustworthy. This is how the reader catches "too good / too bad to be
   true." If the documented result was selected from several explored variants, note that here:
   the selection is part of what makes the result trustworthy or not.
5. **Gaps** — anything the investigation could not recover. Do not hide these.

Write equations as LaTeX math (`$…$`, `$$…$$`) so they render in every target format. Use
American spellings. Keep prose dense and concrete; avoid jargon and triumphal framing.

**Consolidated mode — reconciliation.** When regenerating a living `METHODS.md`, do not blindly
overwrite. Where a later correction (often recorded in the plan's `Working knowledge`) supersedes
an earlier choice, say so explicitly: "this analysis initially assumed X; subsequent work
established Y." A superseded-assumption trail is high-value content here — exactly what a skeptical
reader needs — so this is a deliberate exception to the usual rule against "formerly this…"
history in code and comments.

## Step 4: Render to a rich format

The canonical artifact is Markdown; rich formats are **render targets** produced by **Pandoc**.
Markdown is the ecosystem's lingua franca, is reviewable as-is on GitHub or in any editor with no
tooling, and (with LaTeX math) carries equations and figures correctly to every target.

Render with the fail-fast capability detection your stance calls for — never silently degrade:

1. **Always** the Markdown exists first; it is the reviewable baseline.
2. Probe for renderers and offer the richest available, naming what you found:
   - No `pandoc` → stop at Markdown, and **state so explicitly** with a one-line install hint,
     rather than presenting the Markdown as the finished artifact.
   - `pandoc` + a LaTeX engine (`tectonic` / `xelatex` / `pdflatex`) → offer **PDF** (the
     default), and `.tex` on request for lifting into a manuscript.
   - `pandoc`, no LaTeX → offer **`.docx`** (Word is a first-class option: Pandoc converts LaTeX
     math to native Word equation objects and embeds figures) and/or **self-contained HTML**
     (MathJax, no external dependencies).
3. Default to PDF when a LaTeX engine is present; otherwise `.docx` or HTML. The user may override
   the target at any time.

For figures to embed across targets, prefer **PNG** (LaTeX prefers PDF, HTML loves SVG, Word wants
PNG — PNG is the safe cross-target default). This is the one place this skill leans on the durable
figures specified in `Target Outputs`; do not regenerate figures here.

*Optional upgrade:* if the project already uses **Quarto**, you may render through it instead — it
wraps Pandoc and is cross-language. Do not introduce Quarto as a new dependency; Pandoc is the
baseline.

## Step 5: Active confirmation checkpoint

The point of all of this is alignment, so do not write-and-leave. Close by turning the
**Assumptions to check** list into a short, direct ask: surface the **3–5 riskiest** assumptions
(per the subagent's risk flags) and ask the user to confirm each matches their intent.

Be flexible about the review medium. Some judgments are easy in-session from the Markdown; others
the user can only make from the **rendered artifact** with its real figures and equations. So offer
both paths: a quick in-session confirmation, *and* "render to PDF, read it, come back with
comments." Do not force inline ASCII review when the finished document is what the user needs to
judge.

If the user **rejects** an assumption, you have caught a misalignment — the whole reason this skill
exists. Do not quietly patch the prose. Record it:

- Add it to the plan's `Open Questions` (or `Working knowledge`, if it is a settled correction),
  so the next implementation session acts on it.
- Tell the user plainly which result(s) the misalignment affects and that they likely need
  revisiting.

## Step 6: Persist or discard

- **Consolidated mode**: write/update `METHODS.md` in the project root (or a `docs/` location the
  user specifies), with the reconciliation from Step 3. This is a durable, living document.
- **Focused mode**: write to a temporary file (e.g. `/tmp/methods-<stage>.md`, or the system temp
  directory) and tell the user the path, noting they can copy it somewhere permanent if they
  decide to keep it. Do not clutter the project with one-off methods notes by default.

## Important notes

- **Source of truth is the code, not the project's self-description.** The plan and Notes are
  claims to verify. Re-narrating a possibly-wrong self-account defeats the purpose.
- **Never fabricate.** A recovered gap reported honestly is worth more than a fluent invention.
- **Context frugality is a feature, not an optimization.** Keep the heavy reading in the subagent
  so your judgment in the alignment conversation stays sharp.
- Do **not** modify analysis code or rerun the pipeline here — this skill documents and verifies;
  it does not implement. If it uncovers a bug or misalignment, route it through the plan's
  `Open Questions` for `/new-analysis-implement` to handle.
