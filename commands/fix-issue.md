---
description: triage and fix a single item in a Julia package's issue tracker
---

Run inside a package git-repository. The user supplies a link or issue number
(referencing the `origin` repository) when launching; if not provided, ask.

The goal is to reach the **right** action — which is sometimes a code fix,
sometimes a doc edit, and sometimes a "no change needed" finding. Do not assume
the issue is a bug. Reproduce first, decide second, act third.

## 1. Gather context

- Read the issue thread: `gh issue view XYZ --comments` (resolve a link to its
  number). Note the Julia version, package version, and OS the reporter used,
  plus any stack trace or reproducer they provided.
- Read the conversation in this session and any reference material it points to
  (linked issues/PRs, the relevant source, the docs).
- Skim recent history for an already-landed fix: `git log --oneline -20` and, if
  a commit looks relevant, `git log -S<symbol>` or `gh pr list --search XYZ`.

## 2. Reproduce — build a MWE

Construct a minimal working example that triggers the reported behavior.

- Match the reporter's environment where it matters: the Julia version and the
  local `Project.toml` environment. To pin a version, prefer juliaup's stable
  channel shortcuts — `julia +lts`, `julia +release`, or an exact `julia +1.x` —
  rather than a bare `julia`, whose default channel can be re-linked over time
  and is not guaranteed to be the LTS.
- Iterate through the **Julia MCP server** by default, leaning on `Revise` so
  edits to the source take effect without paying full recompilation each time;
  a persistent session is what makes this tractable. The exception: a few
  packages need a fresh, standalone session for *every* run because their
  behavior depends on precompilation/load state that Revise cannot hot-patch —
  notably Revise itself and its dependencies, and tools like SnoopCompile. When
  the issue is in (or sensitive to) such a package, drive each attempt with a
  fresh `julia` process instead of the shared session.
- Fail fast: if the MWE does **not** reproduce the behavior, that is itself a
  result — do not paper over it with a speculative fix. It points toward
  "already fixed," "reporter-error," or "cannot replicate" (see step 4).

## 3. Decide

From the MWE and root cause, pick exactly one path:

- **Bug to fix** → step 4a.
- **Limitation that should be documented** → step 4b.
- **No package change needed** (reporter-error, already fixed, or cannot
  replicate) → step 4c.

## 4. Act

When you are about to **prepare a change** (4a or 4b), first do a *narrow*
related-work check — this is scoped to getting the current fix right, not to
triaging the tracker:

- Search open PRs and issues for the same root cause:
  `gh pr list --search "<keyword>"` and `gh issue list --search "<keyword>"`.
- If an open PR already fixes it, stop and report that instead of duplicating
  work. If several open issues share one root cause, widen the fix and tests to
  cover them, and list those numbers for the user.

Full duplicate-hunting and tracker cleanup are a separate task; do not expand
into them here.

Then create a fresh branch off the **up-to-date** default branch:

```bash
git fetch origin
git switch -c teh/fixXYZ origin/<default-branch>   # or the branch name the user gave
```

`teh` = user initials, `XYZ` = issue number; the user may instead supply a
branch name at invocation.

### 4a. Fix the bug

- Add the MWE as a regression test. When the issue concerns an error or its
  message, prefer `@test_throws "message users actually see" expr` over (or in
  addition to) the exception type — the message is usually the meaningful target.
- Implement the fix. Annotate argument types only as specifically as the
  implementation requires (see the style guide); fail-fast on genuinely
  unexpected input rather than silently continuing.
- Reference the issue in a code comment (a statement of intent, e.g.
  `# issue #XYZ: ...`), not a history note. Do **not** put the issue number in
  the commit subject.
- Run the test as you iterate, using whichever session model step 2 selected
  (shared MCP session, or fresh process for the fresh-session packages). Reserve
  `Pkg.test()` for a final full-suite pass once you believe the fix is complete.

### 4b. Document the limitation

- Edit the relevant source — README, docstrings, or the Documenter `docs/`.
- If a jldoctest or example demonstrates the behavior, keep it runnable.

### Commit (4a and 4b)

- Commit locally. **Do not push** until the user has reviewed the change and the
  commit message.
- Subject ≤ 50 chars (72 max), no issue number. Put `Fixes #XYZ` in the body so
  GitHub auto-closes on merge (multiple: `Fixes #abc; fixes #def`).

### 4c. Report findings (no change)

Print a concise summary to the user. **Do not post it to GitHub** — the user
handles all communication with the reporter. This path covers:

- the issue is demonstrably reporter-error;
- the issue was already fixed by an earlier commit (include the commit/PR# in
  your summary);
- you cannot replicate the issue (state what you tried and which Julia version —
  e.g. the `+lts` / `+release` / `+1.x` channel you used).
