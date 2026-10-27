---
name: polish-manuscripts
disable-model-invocation: true
argument-hint: "<file.tex> [questions or context] | continue | session N"
description: "Structural and editorial review of a whole manuscript, followed by a tracked series of editing sessions: survey the text, publish a checklist page where the author decides on each item, agree on cross-cutting rules, then carry out the accepted items one fresh-context session at a time."
---

# Polish a manuscript

This workflow has two modes, chosen from the arguments:

- **Start** (`/polish-manuscripts paper.tex [questions or context]`): survey the manuscript, report
  findings, publish a checklist page, and, once the author has responded, plan the
  editing sessions.
- **Continue** (`/polish-manuscripts continue` or `session N`): run the next planned
  session. Find the review page through the project's memory note (Phase 2, step 6),
  not by asking.

If no argument is given, check memory for an open review of a manuscript in this
directory. If there is one, ask whether to continue it or start a new review.

Throughout, the author makes the decisions. The review's job is to find problems, make
concrete proposals with a recommendation, and record what was decided so that later
sessions do not have to re-derive it.

## Style guide

Read `~/.claude/skills/writing-manuscripts/SKILL.md` before surveying or editing. It is
the standard both for judging the prose and for writing new prose. Also read any
project memory notes about manuscript style; they record rulings the author has made
about this particular paper.

## Manuscript context

Each manuscript has its own concerns that a general review would miss. Before the
survey, collect them from:

- the arguments to `/polish-manuscripts`;
- project memory notes about this manuscript (scope rulings, notation decisions,
  related papers);
- the author. If the first two give little, ask once, briefly: "Anything I should
  watch for in particular, or constraints I should know about?" A short answer, or
  none, is fine.

Useful context includes things to watch for in particular (a term the author suspects
is overloaded, a section known to be weak), the audience and venue, material that is
deliberately out of scope, where commits go (e.g. a branch kept until the author
decides to merge), and related manuscripts: companion drafts that share notation,
cite results from this one, or receive material moved out of it. For each related
draft, note its path, the version to read, and what it shares with this one. The
version matters: the current text of a related draft may be on a branch or in a
separate worktree, and its project memory usually says which; ask if it does not.

A related draft may have had its own review. If so, read its recorded decisions: its
memory notes and, if it has a checklist page, the page itself (`Artifact read`; only
the page source holds the item text) and its `feedback` and `status` collections.
Approved renames, notation, and rulings there apply to this manuscript too unless the
author says otherwise, and bringing this manuscript into line with them is part of
the review.

Also list open work already in the repository: plans, handoff files, and TODO
comments in the source. A review that ignores them may propose plans that conflict
with them. Ask the author whether each one still stands.

Save the context as a project memory note (type `project`) named after the
manuscript, with a line in `MEMORY.md`, in the project memory of the directory where
sessions on this manuscript run. Link to it from the review's reference note (Phase
2). Every later session reads it. When a session's discussion adds to the context (a
new ruling, a newly related draft), update the note.

When there are related drafts, add a **Cross-manuscript (X)** question to the survey:
are shared symbols and terms used the same way in both? Are results cited from the
other draft stated the way that draft states them? Does material this review proposes
to move out of this manuscript have a place in the other? Do references into the
other draft still point to the right place?

Start with the cheap, mechanical checks; they find most of the problems in a few
commands:

- grep this manuscript for each old name the related review renamed (its `status`
  notes say what changed, and to what);
- if this manuscript cites the related draft by label (e.g. through the `xr`
  package), list every cited label and check that each exists in the related draft's
  current version. Also check which copy of the related draft the build actually
  reads; it may be a stale checkout.

Then read the parts of the related draft that bear on the remaining questions, and
say which parts were read. Edits to a related draft are out of scope unless the
author asks for them; list them as items so the author can decide.

A rename this manuscript has not yet adopted from the related draft is an X item. A
collision within this manuscript is an N or W item. When adopting a related draft's
symbol creates a collision here, file both and link them with `rel`.

## Phase 1: Survey

The survey is analysis only. Do not edit the manuscript during it.

1. **Record the baseline.** Note the commit hash (`git rev-parse --short HEAD`) and
   whether the `.tex` files have uncommitted changes. Every line number in the review
   refers to that state, so the page must say which commit it is. Also record the
   commit of each related draft that was read; X findings depend on it.
2. **Read the whole main text,** including `\input`/`\include`d sections. Large files
   may need to be read in ranges. If parts are only skimmed (appendices, supplements),
   say exactly which parts in the report; the author needs to know what the review did
   not cover. For a long manuscript, especially one with related drafts to read as
   well, the survey may be delegated to a subagent that follows this phase and
   returns its findings. Before discussing a high-priority finding with the author,
   read the passage behind it yourself.
3. **Assess the author's questions first,** then the default questions below unless
   the author says otherwise. Add any questions the author raises mid-survey. A
   default question with no findings is reported as "none" and gets no group on the
   page.
   - **Titles (T):** does each section title describe its content? Look for
     subsections that do not fit under their parent, `\paragraph`s that are cited as
     if they were numbered sections, and opening paragraphs that promise results
     delivered elsewhere.
   - **Detail (D):** is the level of detail balanced across sections? Implementation
     detail (solver back-ends, storage budgets, stall rules) may belong in an
     appendix or the software documentation.
   - **Results (F):** results prose should defer to the figures. Flag passages that
     narrate what a figure already shows (medians, values for individual points,
     play-by-play), and places where the prose carries something a figure should
     show instead. Also flag experiments whose only role is to confirm a theorem;
     proofs and package tests do that. Experiments should address what the theory
     cannot settle, such as how many iterations convergence takes in practice or how
     tight a bound is. Note any such question the paper raises but does not test.
     Count the numbers in each results subsection; the counts make the case
     concrete.
   - **Notation (N):** symbols with more than one meaning, especially when the
     meanings occur close together, and symbols that conflict with a standard
     meaning this manuscript's content makes likely to come to mind (e.g., in a
     manuscript about eigenvalues, ρ for anything other than the spectral radius
     risks misinterpretation; in other manuscripts ρ may be free). Grep each
     suspect symbol and count its uses.
   - **Terms (W):** one concept under several names, or one name for several
     concepts. Count the variants with grep; numbers make the case concrete.
   - **Ordering (O):** concepts used before they are introduced. An implicit
     dependence, one the reader cannot resolve at the point of use, is a defect. An
     explicit forward reference ("proved in §5, Theorem 3") or a cited appendix
     result is not. Judge by how much the reader must carry before the motivation
     arrives, not by strict linearity. Before proposing to move material, consider
     what the current order does for the reader: motivation often comes before
     machinery for good reason, and rewording a promise ("§5 shows when…") is usually
     better than moving theory forward.
   - **Figure styling (G):** does each concept (a method, a cover, a test set, a
     reference value) keep the same color, marker, line style, and legend label in
     every figure? Do legend and axis labels use the same terms as the prose? Does
     any caption or sentence describe a style ("the blue curve") that the figure no
     longer uses? With related drafts, check whether shared concepts are drawn the
     same way in both. This is analysis: it means reading the plotting scripts and
     looking at the figure files. Delegate it to a subagent (see "Figure-styling
     check" below) and work from the table it returns.
4. **Rate by cost to the reader,** not by the size of the edit. Anything that breaks
   the build (a dangling label, a stale input path) is high regardless.
5. **Report in the terminal.** Group the report by question, most important first
   within each group. For each finding give the location (`file.tex:123`), what is
   wrong, and a concrete suggestion. Mark related findings so the author can see
   which ones go together. End with what was not read and the open questions for the
   author. With more than about 15 findings, the terminal report gives the counts per
   group, the high-priority findings in full, what was not read, and the questions;
   the checklist page carries the rest.

## Phase 2: Checklist page

When there are more than a handful of findings, offer a checklist page in one line: a
private page where the author can accept, modify, reject, or discuss each item and add
a note. The page saves responses to its own database, which later sessions read. Build
it when the author agrees.

1. Load the `artifact-capabilities` skill. The page needs the `db` capability.
2. Write a spec file in the scratchpad with one item per finding. IDs are the group
   letter plus a number (T1, N4, …). Item fields: `id`, `g` (group), `p`
   (`high`/`med`/`low`), `t` (title), `b` (finding), `s` (suggestion), `r` (line refs,
   e.g. `":212"`), `rel` (related IDs). The script's docstring gives the full format.
   Backticks in text render as code. Put the commits from the baseline (this
   manuscript's and each related draft's) in the `eyebrow` or `lede`.
3. Build the page:
   `python3 ~/.claude/skills/polish-manuscripts/scripts/build_review_page.py spec.json review.html`.
   The script fails on duplicate IDs, unknown or empty groups, or dangling `rel`
   references; fix
   the spec rather than working around it.
4. Publish `review.html` with `capabilities: {"db": {}}` and icon `checklist`.
5. Check that the store responds (`ArtifactData list` on `feedback` should return
   nothing). Tell the author what was checked and what was not: the first click on
   the page is the first test of saving from the page.
6. Save a project memory note (type `reference`) with the URL, the commit the line
   numbers refer to, the item ID ranges, the database layout below, and a link to the
   manuscript context note. Add it to `MEMORY.md`.

### Database layout

| Collection | Written by | Fields |
|---|---|---|
| `feedback/<id>` | page (author) | `decision` (accept, modify, reject, discuss, or null), `note`, `updatedAt` |
| `feedback/_general` | page (author) | `note`: general comments or policy |
| `status/<id>` | Claude | `state` (e.g. `done`, `no-action`, `waiting-on-runs`, `plan revised`), `note` |
| `sessions/s<N>` | Claude | `n`, `title`, `state` (planned, in progress, waiting, done), `scope`, `note`, `items` (list of IDs) |

The page displays `status` on each item and renders `sessions` as a work plan with
links to the items. A `status` of `done` puts a check mark on the item in the plan.
Writes to an existing document need `if_version`; use `batch` for several writes.

## Phase 3: Read the responses and discuss

When the author says they have responded:

1. Read all of `feedback`, including `_general`. Read every note; a note often matters
   more than its decision.
2. **Discuss only what cuts across items now.** Leave item-specific discussion for the
   session that will handle the item. Look for:
   - a rule the review applied that the author does not hold. Say so plainly and
     withdraw the affected proposals, then save the corrected rule as a `feedback`
     memory so later reviews do not repeat it.
   - a framing error, such as a term defined more narrowly than the author intends,
     that changes several items at once.
   - structural proposals in the author's notes. Turn these into a concrete order or
     outline for them to confirm.
   - choices that are the author's to make. Give a recommendation for each.
3. Record outcomes on the page: write `status/<id>` with a short "plan revised: …"
   note on each item the discussion changed, and `no-action` on items that need none.

## Phase 4: Plan the sessions

A session is one fresh context window: the author types `/clear` and pastes a start
prompt. Fresh contexts leave room to read the sections a session rewrites, and they
keep analysis separate from writing (see below).

Group the accepted items into sessions:

- **Session 0: naming and notation decisions.** Renamed terms and symbols affect
  every later rewrite, so settle them first. This session draws from the N and W
  items and from the X items that adopt a related draft's names. It is mostly
  proposals and discussion; implement the renames once they are approved.
- **Then one session per structural change,** in dependency order. If one section
  moves material that another cites, the move goes first.
- **Experiments and figures** are often independent of the text restructuring and
  may be waiting on new runs; mark those items `waiting-on-runs`.
- **Figure styling** gets a session of its own, because it is script work, not
  prose. Run it after session 0, so legend labels can use the settled names. It
  changes the plotting scripts, ideally so that every script takes each concept's
  style from one shared definition. It ends with the list of figures to regenerate
  and the captions or sentences that mention a style, which go to a writing session.
- **A final sweep:** consistency of terms and symbols across the whole text, a clean
  compile, and the list of figures to regenerate.

Write each session to `sessions/s<N>`, explain the plan to the author, and update the
memory note with the session list and order.

## Phase 5: Run a session

1. **Load state.** Read the review's memory note and the manuscript context note,
   then `feedback`, `status`, and `sessions`.
   Set the session's state to `in progress`. Read the session's `note`; earlier
   sessions leave instructions there.
2. **Read before writing.** Read the style guide, the sections being changed, and
   every section they depend on. Grep each symbol or term before introducing it, to
   avoid collisions.
3. **Proposals first when the item calls for it.** For items marked `discuss` or
   `modify`, or with an open question in the note, propose and wait for the author's
   answer before editing. For each proposal give a recommendation, an alternative if
   there is a reasonable one, and the counts or locations it rests on. A table works
   well for symbol renames.
4. **Renames.** Count the uses and separate the named uses from generic uses of the
   same word ("a covariant start" may be a generic use even if "covariant start" is
   being renamed). Check figure titles, axis labels, legends, and the scripts that
   generate the figures. List the figures that need to be regenerated, since changing
   a script does not change the existing PDF.
5. **Code changes.** If a rename reaches a software package (an option name, a
   keyword), write a handoff file (markdown) in the package's repository, or
   (for small changes) delegate that change to a subagent on a branch in the
   package's repository. Anything that may require interaction with the user
   should be handled via the handoff file.
6. **Revise before showing.** Draft first, then make a separate sentence-by-sentence
   pass against the style guide before showing any new paragraph. Prose shown inside
   a proposal is still read as prose.
7. **Compile and check.** Build the manuscript (e.g. `latexmk`) and confirm there are
   no errors and no undefined references or citations. Then grep for leftovers of
   anything renamed.
8. **Commit only your own changes.** The author may have uncommitted work in the same
   files: stage only your hunks (`git add -p`, or apply a patch of just your lines to
   the index). Ask once per review where commits go (e.g. manuscript on `main`, package
   on a branch) and record the answer in the memory note.
9. **Close the session.** Write `status/<id>` for each finished item (with the commit
   hash), set the session to `done` with a note that says what remains, and put
   anything the next session must do first into that session's `note`. Then give the
   author the prompt for the next session, ready to paste, e.g.

   > Start session 2 of the manuscript review work plan. Begin with the N10 investigation and discuss it with me before implementing anything.

   and tell them to type `/clear` first.

## Analysis and writing are separate

Do not mix analysis (reading code or logs, checking numbers, deriving results) with
drafting prose in one session. If a session's items need analysis, do that analysis
and report it, and leave the drafting to a later session that works from the report
and the `.tex` alone. If a number in the text looks wrong during a writing session,
record it as a question for the author rather than investigating it.

The user may also permit analysis using a subagent.

## Figure-styling check

Give the subagent the manuscript path, the list of figures it includes, and where the
plotting scripts live. Ask it to:

- find, for each figure, the script that draws it and the style each plotted concept
  receives (color, marker, line style, legend label), and confirm against the figure
  file itself (the Read tool displays PNG images; render PDF figures to PNG first);
- return a table with one row per concept and one column per figure, followed by the
  inconsistencies it found, each with the script and line that sets the style;
- note captions and prose that refer to a style, with line numbers;
- edit nothing.

Turn its inconsistencies into G items. If the scripts already share a style
definition, say so; if not, recommend one as a G item.

## Delegated checks

Literature checks (e.g. which convention a notation usually follows) can run in a
subagent on a cheaper model while the main session continues. Tell the subagent to
search and to return a source for each claim. If it answers from memory, say so when
reporting, and verify the source before citing it in the manuscript.

## Reporting

When reporting to the author, say what was verified and what was not. Examples: "the
page's database responds, but saving from the page has not been tried"; "the page's
script was not syntax-checked". Also say which tests a delegated code change ran and
which it skipped.
