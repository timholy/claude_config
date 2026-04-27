---
description: Read a Julia package's src/, test/, and docs/ to produce a purpose summary and conceptual map for design review
model: Sonnet
effort: low
---

Read all of `src/`, `test/`, and any README or `docs/` material in the current working directory. Produce and return exactly two artifacts:

**Phase 1 — Purpose summary**: A one-paragraph summary of what problem the package solves, who the intended users are (domain experts? Julia generalists? Other package authors?), and what the central abstraction is, if there is one.

**Phase 2 — Conceptual map**:
- **Types**: Every exported or `public` type, plus any unexported types that appear in public function signatures. For each, note its role: data container, algorithm parameter, result type, trait, etc.
- **Operations**: Every exported or `public` function and macro, grouped by what they operate on. For each group, note the rough shape of the operation: construction, transformation, query, reduction, side effect, etc. For each non-exported, non-`public` function or macro that is either (1) demonstrated in docstrings, README, or `docs/` material or (2) called directly (with namespace qualification) from the test suite, note it along with which of these usage categories it exhibits.

Return only these two artifacts — not the raw source.

Err toward completeness over brevity in the conceptual map. It is better to include a marginal type or function than to omit one the reviewer will need — the conceptual map is the sole input to a reasoning pass that cannot go back to the source.
