---
description: Update .gitignore for a Julia package to cover coverage files, manifests, and docs build artifacts
model: Sonnet
effort: low
---

Ensure the Julia package in the current directory has an appropriate `.gitignore`. The following must be covered, anywhere they appear:

- `*.jl.cov`, `*.jl.*.cov`, `*.jl.mem`
- `Manifest.toml` and `Manifest-v*.toml` (in root and in `docs/` if present)
- `docs/build/` if the package has Documenter docs

Check the existing `.gitignore` (if any) and add only what is missing. Do not remove existing entries.
