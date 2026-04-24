---
description: Format a Julia package with runic, commit as a standalone PR, update .git-blame-ignore-revs, and install the runic post-edit hook
---

Format the Julia package in the current directory using `runic`, following these steps in order:

## 1. Format source files

Run `runic -i` on all applicable directories:
- `src/` (always)
- `ext/` (if it exists)
- `test/` (if it exists)

Also ensure that any tests are wrapped in an appropriately-named `@testset`.

## 2. Verify tests pass

Run the test suite:
```
julia --project -e 'using Revise, TestEnv; TestEnv.activate(); include("test/runtests.jl")'
```

Fix any failures before continuing.

## 3. Commit and open a PR

Stage all formatting changes and commit with a message like "Apply runic formatting". This commit must contain **only** formatting changes — no functional changes. Open a pull request.

**Pause here and wait for the user to confirm the PR has been merged before continuing.**

## 4. Update .git-blame-ignore-revs

After the PR merges, add the merge commit SHA to `.git-blame-ignore-revs` (create the file if needed):

```
# runic formatting
<sha>
```

Then configure the repo to use it:
```
git config blame.ignoreRevsFile .git-blame-ignore-revs
```

Commit this file.

## 5. Install the runic post-edit hook

Create `.claude/settings.json` in the project root with the following content (merge with any existing content rather than overwriting):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "python3 -c \"import sys,json; d=json.load(sys.stdin); print(d['tool_input'].get('file_path',''))\" | { read -r f; [[ \"$f\" == *.jl ]] && runic -i \"$f\"; } 2>/dev/null || true",
            "statusMessage": "Formatting Julia with Runic..."
          }
        ]
      }
    ]
  }
}
```

Add `.claude/settings.json` to the repo and commit it.
