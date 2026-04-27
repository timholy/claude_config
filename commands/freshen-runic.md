---
description: Format a Julia package with runic, commit as a standalone PR, update .git-blame-ignore-revs, and install the runic post-edit hook
---

Format the Julia package in the current directory using `runic`, following these steps in order:

## 1. Verify tests pass

Run the test suite:
```
julia --project -e 'using Pkg; Pkg.test()'
```

If there are failures, **do not continue**. Tell the user that this cannot continue until tests pass.

## 2. Verify a "clean slate"

Check that all of the following are true:

- the default branch is currently checked out
- there are no unmerged changes in tracked files
- the repository either lacks `.claude/settings.json` or that file lacks the string "runic -i"

If any item on the list is false, **do not continue**. Report reason for stopping to the user.

## 3. Format source files

Run `runic -i` on all applicable directories:
- `src/` (always)
- `ext/` (if it exists)
- `test/` (if it exists)

Also ensure that any tests are wrapped in an appropriately-named `@testset`.

## 4. Commit and open a PR

Check out a branch, stage all formatting changes, and commit with a message like "Apply runic formatting". This commit must contain **only** formatting changes — no functional changes. Open a pull request.

**Pause here and wait for the user to confirm the PR has been merged before continuing.**

## 5. Update .git-blame-ignore-revs

After the PR merges, add the merge commit SHA to `.git-blame-ignore-revs` (create the file if needed):

```
# runic formatting
<sha>
```

Then configure the repo to use it:
```
git config blame.ignoreRevsFile .git-blame-ignore-revs
```

## 6. Install the runic post-edit hook

Create or extend `.claude/settings.json` in the project root to contain the following content (merge with any existing content rather than overwriting):

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

Stage `.claude/settings.json`. Prepare a proposed commit message and ask the user whether it should be committed.
