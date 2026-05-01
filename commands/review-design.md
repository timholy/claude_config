---
description: Review a Julia package's design for conceptual coherence: scope, type hierarchy, overlaps, abstraction level, and composability
model: Opus
effort: high
---

Review the Julia package in the current working directory for conceptual design issues. This is not a correctness check or a convention check — assume the code runs and follows modern Julia idioms. The question is whether the package's design is internally coherent: does it have a clear identity, a sensible type hierarchy, a consistent level of abstraction, and an API that composes naturally without exposing implementation accidents?

This skill produces a structured report, then a values-clarification discussion, then a `DESIGN_REVIEW_PLAN.md` that decomposes the agreed-upon findings into chunks consumed by the companion `/review-implement` skill. Many findings will be questions for the author rather than clear recommendations, because the right answer often depends on design intent that only the author knows. Do not implement any changes in this skill — that is `/review-implement`'s job.

The package module name is determined from `Project.toml`.

---

## Phases 1 + 2 — Understand the package and build a conceptual map

Invoke the `pkg-conceptual-mapper` subagent on the current working directory. It will return a **purpose summary** (Phase 1) and a **conceptual map** of types and operations (Phase 2). Work from those two artifacts — do not re-read the source — to run the coherence checks below.

---

## Phase 3 — Coherence checks

Work through each of the following. For each finding, record: what you observed, why it may be a problem, and what question you would ask the author to determine whether it is intentional.

### 3a. Scope coherence

Does every exported name clearly belong to the package's stated purpose from Phase 1? Look for:
- Functions that feel like general utilities unrelated to the package's domain (often extracted from application code and left in)
- Functionality that is large enough and distinct enough that it might belong in a separate package
- Conversely, functionality that is missing and whose absence forces users to re-implement obvious things

### 3b. Type hierarchy

Does the type hierarchy reflect the actual conceptual relationships in the domain?
- Abstract types that have only one concrete subtype (usually a sign the abstraction is speculative rather than load-bearing)
- Concrete types that should probably be abstract (because users would naturally want to provide their own implementations)
- Types that are conceptually related but have no declared relationship in the type hierarchy
- Types whose fields expose implementation details that users should not need to know (consider whether these should be opaque)
- Parametric types with type parameters that are never meaningfully dispatched on (the parameter may be unnecessary)

### 3c. Overlapping operations

Are there pairs or groups of functions that do similar things without a clear differentiation?
- Functions that are special cases of each other, but neither calls the other (code duplication masquerading as API)
- Functions whose names suggest they are related but whose implementations diverge more than expected
- Functions that are distinguished only by an argument that should instead be a dispatch type

For each overlap, ask: should one be removed? Should one call the other? Should they be unified?

### 3d. Implied but absent operations

Given the operations that exist, are there natural operations that are absent?
- If `foo_to_bar` exists, should `bar_to_foo`?
- If a type can be constructed, can it be serialized/deserialized if that is natural for its domain?
- If `f!` exists, is there a natural use case for the non-mutating `f` that users would expect?
- If the package defines a container type, does it support the iteration and indexing operations that users would expect from a Julia container?

- If a type has a custom `show` method whose output contains all the information needed to unambiguously reconstruct the object, but that output is not valid Julia syntax, consider whether a `Base.parse` method should exist. The test: could a user copy the REPL output and paste it back to recreate the value? If the answer is "no, but all the information is there," that is a gap worth flagging.

Do not flag absences that are obviously out of scope — focus on things a user would reasonably look for and be surprised not to find.

### 3e. Abstraction level

Is the exported API at a consistent level of abstraction?
- A mix of high-level "do the whole thing" functions and low-level "one step of the algorithm" functions in the same export list can be a sign that internal helpers leaked into the public API
- Low-level functions that are exported "just in case" but have no documented use case outside the package itself
- Conversely, a high-level API with no escape hatches — users who need finer control have no path to it

### 3f. Composability

Do the package's own functions compose naturally with each other and with Base?
- Output types of one function that cannot be passed directly to another related function — requires unpacking and repacking
- Functions that return results in a format that is inconvenient to use with standard Julia tools (`map`, broadcasting, comprehensions)
- Types that participate in the package's own operations but do not implement standard Julia interfaces (`iterate`, `getindex`, `show`, etc.) that would make them broadly usable
- Types that define `==` (i.e., extend `Base.:(==)`) but do not define a matching `Base.hash` — the default `hash` is identity-based, so such types will silently misbehave as `Dict` keys or `Set` elements. Conversely, check that any custom `hash` is consistent with `==`: `isequal(x, y)` must imply `hash(x) == hash(y)`. Note that `isequal` falls back to `==` for most types, so defining `==` without `hash` is the common failure mode.

### 3g. Relationship to Base and the standard library

What does this package provide that Base does not, and is the boundary clear?
- Functions that duplicate Base functionality for the package's types but with different names (when extending `Base.f` with a new method would be more natural)
- Functions that shadow Base names but with different semantics (a significant source of user confusion)
- Types that implement interfaces (iteration, arithmetic, comparison) inconsistently with how Base types implement them

### 3h. Error and failure model

Is the package's approach to errors and missing results consistent?
- Some functions throw on bad input, others return `nothing`, others return a sentinel value — is there a coherent philosophy, or is it historical accident?
- Functions that return `nothing` for "not found" vs. functions that throw — users need to know which to expect
- Functions that accept invalid input silently (returning a meaningless result) vs. those that validate eagerly

### 3i. Missing `public` annotations

Record any non-exported, non-public operations together with a statement saying whether it appears in documentation and/or tests.

---

## Phase 4 — Report

Structure the report in three sections:

**Likely design issues**: Findings where the evidence strongly suggests an accidental or inconsistent choice — not a matter of preference, but something that would probably be changed if the author looked at it fresh. Include specific examples (function names, type names, line numbers).

**Design questions**: Findings that could be intentional but which are worth discussing. For each, frame it as a question: *"Function X does Y, but given that Z also exists, was the intent to...?"* The author may have a good reason; the goal is to surface the question.

**Observations**: Minor things that are not clearly problems but that a design-conscious reader would notice. These may inform future decisions even if no action is taken now. Non-exported, non-public operations that might be intended for external users should be noted here.

End the report with a short paragraph characterizing the overall design: what works well, what the main tension is (if any), and what the one or two highest-leverage changes would be if the author wanted to address the findings.

Present the report to the user and discuss. Do not propose specific code changes yet — Phase 5 captures the author's reaction, and Phase 6 turns the agreed-upon findings into an implementable plan.

---

## Phase 5 — Values clarification

A design review surfaces tensions; resolving them requires the author to
articulate (or re-articulate) what the package is *for*. Before any plan is
written, ask the author to answer briefly, in their own words:

1. **Scope and audience**: who is this package for, and what is explicitly
   *out* of scope? If the review surfaced a finding that suggests the scope
   is unclear (e.g., utilities that look like a separate package), this is
   the moment to settle it.
2. **Central abstraction**: is there one? If the review identified the type
   hierarchy as load-bearing or speculative, name what should be the
   conceptual centerpiece going forward.
3. **Composability and Base relationship**: how aggressively should the
   package participate in standard Julia interfaces (iteration, indexing,
   `==`/`hash`, `show`/`parse`)? What's the boundary with Base?
4. **Error and failure model**: what should the consistent philosophy be
   (throw vs. `nothing` vs. sentinel)?

The author may push back on findings ("this is intentional, here's why").
Record those responses — they may turn findings into `dropped` chunks rather
than action items.

The output of this phase is a short paragraph (or short bullet list) that
will be transcribed verbatim into the plan's `Stated values` section. The
implementer skill reads it every session as the tiebreaker for ambiguous
decisions.

Also ask, briefly:

- **Release strategy** (only if any acted-upon finding is likely to be
  breaking): do you want to cut a final non-breaking release before the
  first breaking change lands? If multiple breaking clusters are likely,
  do you want to release between clusters or batch into one terminal
  breaking release? Acceptable answers include `decide-later`, in which
  case the implementer will ask at the relevant moment.

---

## Phase 6 — Write the plan

Walk the author through the report and ask which findings they want to act
on. For each, classify as:

- `decide` — the finding raises a question the author hasn't answered yet
  (often from the *Design questions* section). The implementer will pose
  the question and capture the answer.
- `investigate` — the finding requires read-only research before any code
  change can be planned (e.g., "audit all callers of `foo`").
- `implement` — the change is well-defined enough to code now.
- `dropped` — the author has chosen not to act on this finding. Record the
  reason briefly in the plan.

Group related findings into **clusters** (e.g., "type-hierarchy-cleanup",
"composability-with-base") so the implementer can warn the author about
half-modernized clusters.

For each finding flagged as `Breaking`, mark the chunk accordingly so the
implementer triggers the deprecation/version-bump machinery.

Write the plan to `DESIGN_REVIEW_PLAN.md` in the project root using this
schema:

```markdown
# Design Review Plan
<!-- Auto-generated by /review-design. Edit freely, but preserve chunk IDs and status values. -->

## Metadata
- **Kind**: `design`
- **Package**: [name]
- **Source review date**: [YYYY-MM-DD]
- **Current version**: [from Project.toml]

## Stated values
[paragraph or bullets from Phase 5]

## Release strategy
- **Pre-breaking-release**: `yes` | `no` | `decide-later` | `n/a (no breaking changes planned)`
- **Inter-cluster releases**: `yes` | `no` | `decide-later` | `n/a`

## Baseline
- Tests pass on the starting commit: `not-yet-checked`
- `Test.detect_ambiguities` count: `not-yet-checked`
- Working tree clean: `not-yet-checked`

## Decisions
<!-- Answers to `decide` chunks land here, with the chunk ID. -->

## Chunks

### CHUNK-001: preflight
- **Kind**: `preflight`
- **Originating finding**: n/a
- **Cluster**: none
- **Breaking**: no
- **Description**: Establish baseline (tests pass, ambiguity count, clean tree).
- **Depends on**: none
- **Verification**: full test suite, `Test.detect_ambiguities`
- **Status**: `not-started`
- **Notes**:

### CHUNK-002: [verb-phrase-name]
- **Kind**: `decide` | `investigate` | `implement`
- **Originating finding**: [section / quoted phrase from the review report]
- **Cluster**: [label or "none"]
- **Breaking**: yes | no
- **Description**: [what the chunk does or asks]
- **Depends on**: [CHUNK-XXX, ... or "none"]
- **Verification**: [tests / ambiguity check / "n/a (decide)"]
- **Status**: `not-started`
- **Notes**:

[... additional chunks ...]

## Session Log
<!-- The implementer appends an entry after each session. -->

## Open Questions
```

If any chunks are marked `Breaking: yes`, append a terminal `version-bump`
chunk depending on every breaking chunk (and on any `release-breaking`
chunks if `Inter-cluster releases` is `yes`).

After writing the file, brief the user:

1. How many chunks the plan contains and what kinds.
2. The release strategy as recorded.
3. To begin work, run `/review-implement`. The plan is a living document —
   they can edit it freely between sessions.
