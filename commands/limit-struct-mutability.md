---
description: analyze `mutable struct`s for mutation patterns, mark fields as `const`
---

## 1. Analyze `mutable struct`s

Perform a whitespace-insensitive search for `mutable struct` definitions in `src/` or `ext/`.

If any are found, report them to the user and ask if they want to run a full analysis.

If none are found, or the user declines, this task can be terminated. If it has been called from `/freshen-package`, the step should be marked as "DONE".

## 2. Analyze access patterns

Perform the analysis in a subagent. Read the code in `src/`, `ext/`, and `test/`. Note the full list of fields in the order they appear in the type definition, and whether each (1) is already declared `const`, (2) is omitted in any partial `new` constructor, and (3) any package code or test mutates it after construction.

The subagent should return this information as a structured list, one for each `mutable struct`.

## 3. Propose changes

In the main session, analyze the report and assess whether some fields could be marked `const`. For any candidates, assess whether field-reordering is required: any fields to be marked as `const` must appear before any fields omitted in partial `new` constructors.

If reordering is required:
- use Julia's `fieldoffset` (via MCP) to determine the memory layout of the `struct`
- propose a reordering that aims for compact layout. Ties should be broken by preserving existing order.

Propose any changes to the user. **Ask for approval before proceeding.**

If the user declines, terminate the task. If it has been called from `/freshen-package`, the step should be marked as "DONE".

## 4. Implement changes

Implement any agreed-upon changes.
