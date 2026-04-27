---
description: Read a Julia package's src/ to produce a structured public API inventory for convention review
model: Sonnet
effort: low
---

Read all files in `src/` in the current working directory. Identify every exported or `public`-annotated function, macro, and type. For each function, record its full set of method signatures (argument names, types, and keyword arguments). Also note functions not exported but intended for `Module.name`-style use (e.g., documented but not exported).

Return a structured list — not the raw source.

Err toward completeness over brevity. If a signature is missing from the inventory, it cannot be checked for convention issues — include every method, even ones that look trivial or internal.
