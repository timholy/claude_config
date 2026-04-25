---
description: Review a Julia package's design for conceptual coherence: scope, type hierarchy, overlaps, abstraction level, and composability
---

Review the Julia package in the current working directory for conceptual design issues. This is not a correctness check or a convention check — assume the code runs and follows modern Julia idioms. The question is whether the package's design is internally coherent: does it have a clear identity, a sensible type hierarchy, a consistent level of abstraction, and an API that composes naturally without exposing implementation accidents?

This skill produces a structured report and discussion, not a to-do list. Many findings will be questions for the author rather than clear recommendations, because the right answer often depends on design intent that only the author knows. Do not implement any changes — the output of this skill is input to a conversation.

The package module name is determined from `Project.toml`. Read all of `src/`, `test/`, and any README or `docs/` material before forming judgments.

---

## Phase 1 — Understand the package's stated purpose

Read the README (and the top-level docstring of the main module if one exists). Write a one-paragraph summary of:
- What problem the package solves
- Who the intended users are (domain experts? Julia generalists? Other package authors?)
- What the central abstraction is, if there is one

This summary will serve as a reference point for all subsequent phases.

---

## Phase 2 — Build a conceptual map

From reading `src/`, construct two lists:

**Types**: Every exported or `public` type, plus any unexported types that appear in public function signatures. For each, note its role: is it a data container, an algorithm parameter, a result type, a trait, something else?

**Operations**: Every exported or `public` function and macro, grouped by what they operate on. For each group, note the rough shape of the operation: construction, transformation, query, reduction, side effect, etc.

Do not evaluate yet — just map.

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

---

## Phase 4 — Report

Structure the report in three sections:

**Likely design issues**: Findings where the evidence strongly suggests an accidental or inconsistent choice — not a matter of preference, but something that would probably be changed if the author looked at it fresh. Include specific examples (function names, type names, line numbers).

**Design questions**: Findings that could be intentional but which are worth discussing. For each, frame it as a question: *"Function X does Y, but given that Z also exists, was the intent to...?"* The author may have a good reason; the goal is to surface the question.

**Observations**: Minor things that are not clearly problems but that a design-conscious reader would notice. These may inform future decisions even if no action is taken now.

End the report with a short paragraph characterizing the overall design: what works well, what the main tension is (if any), and what the one or two highest-leverage changes would be if the author wanted to address the findings.

Present the report to the user and discuss. Do not propose specific code changes — if the user decides to act on a finding, treat that as a new task.
