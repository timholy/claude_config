---
description: Implement the next chunk of a planned design or API review. Reads DESIGN_REVIEW_PLAN.md or API_REVIEW_PLAN.md, implements one chunk (with a narrow batch exception for `decide` chunks), updates the plan, and prepares a clean handoff for the next session.
model: Opus
effort: medium
---

# Review Implement

You are the implementation engine for a planned design or API review. You work
one chunk at a time, maintain the plan as persistent state, and hand off cleanly
so the next session can begin without context from this one. Use this skill only
when a `DESIGN_REVIEW_PLAN.md` or `API_REVIEW_PLAN.md` exists in the project root.

## Step 1: Orient

Detect which plan file is present:

- `DESIGN_REVIEW_PLAN.md` → design review
- `API_REVIEW_PLAN.md` → API review

If both exist, ask which one to work on this session. If neither exists, stop and
tell the user to run `/review-design` or `/review-api` first.

Read, in order:

1. The plan file. Identify:
   - Package name, current version, kind (design vs api).
   - The `Stated values` section — this is the tiebreaker for ambiguous decisions.
   - The `Release strategy` section — pre-breaking release? inter-cluster releases?
   - Any answers already recorded in `Decisions`.
   - Cluster status (which clusters still have chunks remaining).
   - The next chunk(s) with status `not-started` whose dependencies are all `complete`.
2. The matching session handoff (`DESIGN_REVIEW_SESSION.md` or
   `API_REVIEW_SESSION.md`) if present — this is the previous session's note to you.

If every chunk is `complete` or `dropped`, congratulate the user and suggest
reviewing the `Session Log` for a summary.

## Step 2: Pick the next chunk(s)

Default rule: **one chunk per session**. Two narrow exceptions:

1. **Batch all ready `decide` chunks**. They produce no diff and are cheap to
   answer; doing them up front unblocks downstream `implement` chunks.
2. **Continuation within the same session**: only if the user explicitly asks.
   Recommend they run `/context` first. If context is comfortably below the
   warning threshold and the next chunk is small or closely related, proceeding
   without `/clear` is fine. Otherwise prefer a clean break.

Before doing any work, tell the user which chunk(s) you intend to take, what
verification you plan, and any concerns. Pause briefly for redirection — do not
demand explicit confirmation on routine chunks.

## Step 3: Implement, by chunk kind

### Kind: `preflight`

This is CHUNK-001 in every plan. It establishes the baseline before any change.

- Confirm working tree is clean (`git status`). If not, surface the issue and stop.
- Run the full test suite via the MCP Julia session.
- Run `Test.detect_ambiguities(MyPkg)` and record the count.
- Note the current `Project.toml` version.
- Fill the `Baseline` section of the plan. Mark the chunk `complete`. No commit.

### Kind: `decide`

The chunk encodes a question that needs an author's decision before implementation
can proceed.

- Quote the originating finding so the user has context.
- Pose the question. If you have a recommendation, give it briefly, grounded in
  `Stated values`.
- Capture the user's answer in the plan's `Decisions` section, tagged with the
  chunk ID. Be concise but include enough rationale to reconstruct the choice
  later.
- Mark `complete`. No commit unless the answer demands an immediate doc edit.

### Kind: `investigate`

- Perform read-only research (grep, read files, MCP queries).
- Write findings into the chunk's `Notes` field.
- If the work suggests new chunks (e.g., "this affects 4 call sites, each its
  own implement chunk"), add them in dependency order with status `not-started`
  before closing.
- Mark `complete`. No commit unless the investigation produced an artifact under
  version control (rare).

### Kind: `implement`

1. Make the change.
2. If `Breaking: yes`:
   - Add a deprecation shim where appropriate (`Base.@deprecate` or a manual
     deprecation warning forwarding to the new signature).
   - Migrate all internal call-sites within the package (tests, docstrings,
     examples, internal callers).
3. Add the planned tests.
4. Run the full test suite via MCP.
5. Run `Test.detect_ambiguities(MyPkg)` and compare against the baseline. Flag
   any new ambiguities; investigate before declaring the chunk complete.
6. Stage the changes for the user's review. Do not commit yourself.

### Kind: `version-bump`

Auto-appended whenever any `Breaking: yes` chunk exists. May be the only
version bump (single terminal release) or one of several (per-cluster releases),
depending on the recorded `Release strategy`.

- Verify every dependency (the breaking chunks it covers) is `complete` and that
  no covered cluster is half-finished.
- Update `Project.toml`: bump minor for 0.x with breaking changes; bump major
  for ≥1.x breaking changes; bump patch/minor for non-breaking improvement
  releases.
- Update `CHANGELOG.md` if one exists.
- Stage for the user's review.

### Kind: `release-baseline` / `release-breaking`

Coordination chunks that do not modify package source. Inserted by the planning
skill or mid-pipeline (per Step 5) when the user opts for a release at this
point.

- Confirm tests pass and the tree is clean.
- Walk the user through the release steps explicitly: bump `Project.toml`,
  commit, tag, request registration via `JuliaRegistrator` on the merge commit
  (or the user's preferred mechanism). Be explicit that the Julia registry is
  separate from git tags — registration is its own step.
- Do **not** perform the registration yourself. Releases are user actions.
- Mark `complete` once the user confirms the release has been requested.

## Step 4: Scope discipline

- Implement only the current chunk. If you notice related problems, record them
  in `Open Questions` rather than fixing in-flight.
- If the chunk turns out larger than expected, do the core and split the
  remainder into new chunks before closing.

## Step 5: Update the plan

After implementation:

1. Update the chunk's `Status` to `complete` (or `blocked` / `dropped` with a
   one-line reason).
2. Fill `Notes` with decisions, deviations, and anything the next session needs.
3. Add any new chunks discovered during work in dependency order.
4. Append one paragraph to `Session Log`:

   > **Session YYYY-MM-DD**: Implemented CHUNK-XXX (name). [1–2 sentences on
   > what was built and any notable decisions.] Next up: CHUNK-YYY (name).

5. **Cluster check**: if the chunk belongs to a cluster with remaining chunks,
   note this in the close-of-session message. Half-modernized clusters are a
   known failure mode.
6. **Pre-breaking-release prompt** (only if `Release strategy` says
   `decide-later`): if the next ready chunk is the first `Breaking: yes` chunk
   in the plan, ask whether to cut a final non-breaking release first. If yes,
   insert a `release-baseline` chunk before it and update `Release strategy`.
7. **Inter-cluster release prompt** (only if `Release strategy` says
   `decide-later`): if multiple breaking clusters remain, ask whether to release
   between them or batch into one terminal breaking release. Insert
   `release-breaking` chunks accordingly. Update `Release strategy`.

## Step 6: Write the session handoff

Write (overwriting) `DESIGN_REVIEW_SESSION.md` or `API_REVIEW_SESSION.md`:

```markdown
# Session Handoff — YYYY-MM-DD

## Plan
[DESIGN|API]_REVIEW_PLAN.md — [package name, current version]

## What was just completed
CHUNK-XXX: [name]
[2–3 sentences describing what was implemented.]

## Key decisions / shim choices
- ...

## State of the codebase
- Files modified: [list]
- Test suite: [pass / fail / n/a]
- Ambiguity count: [N (delta from baseline, or "n/a")]
- Staged but uncommitted: [yes / no]

## Cluster status
- [cluster-label]: X of Y complete

## Next chunk
CHUNK-XXX: [name] — [brief]

## Watch out for
[gotchas, fragile assumptions, things the next session should know]
```

## Step 7: Close the session

Tell the user, in this order:

1. What was completed and what verification showed.
2. Cluster status, calling out any half-finished cluster explicitly.
3. A one-line preview of the next chunk.
4. **Review-now invitation**:

   > Now is the best time to review these changes. I have full context on every
   > decision in this chunk and can explain or revise anything while it's fresh.

5. **Commit prompt** (if anything is staged):

   > When you're satisfied, please commit this chunk as a clean standalone unit
   > (e.g., `git add -p && git commit`).

6. **PR nudge** (non-blocking; skip on `decide`/`investigate` chunks that
   produced no commit):

   > Consider opening a PR for this chunk now, or holding until the cluster is
   > complete and submitting the cluster as one PR. Smaller PRs are easier to
   > review than one bundled mega-PR, but use your judgment.

7. **Continuation guidance**:

   > To continue: run `/context` first. If you have plenty of room and the next
   > chunk is small or closely related, you can run `/review-implement` again
   > in this session. Otherwise `/clear` and re-run for a fresh context.

If a `release-baseline` or `release-breaking` chunk just completed, also remind
the user that registering the release on the Julia registry is a separate
action from the commit/tag and confirm they have done so before moving on.

## Important notes

- Do not invent new chunks unless the work demands it; trust the plan.
- If `Stated values` would justify a different choice than the originating
  finding suggested, follow `Stated values` and record the divergence in
  `Notes`.
- Do not register a release on the user's behalf — releases are user actions.
- If the user reports a regression after a chunk landed, treat it as a new
  chunk: write a failing test first (if reproducible without external data),
  add it to the plan, then fix.
