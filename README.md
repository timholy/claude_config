This repository holds my personal configuration for agentic coding. Unless you are a Julia user, it may not be relevant for you.

I'm making it public for the benefit of people in my laboratory and any other users who might want to learn from it. However, it is not intended to be a common resource, and issues/pull requests may be ignored. However, you are welcome to copy or fork this as you see fit (see LICENSE.md).

For me, this repo is my `~/.claude` folder with a lot of required material `git-ignore`d; if you want to use tools from here, either copy the useful bits into your own `~/.claude` or rename your existing `~/.claude` to a temporary name, clone your fork of this repo as your `~/.claude`, and then manually copy all the missing pieces from your old renamed folder.

In addition to CLAUDE.md, a few skills are stored in `commands/`. Most of these skills focus on package maintenance, things like:

- whole-package review for adherence to standard Julia style (`/review-api`)
- docstring completeness, correctness, clarity, conciseness (`/freshen-docstrings`)
- Adding Aqua (`/freshen-aqua`) and ExplicitImports (`/freshen-explicit-imports`) checks

Most of these skills have been tweaked to enhance context-window efficiency; `freshen-docstrings` is a good example, where we extract as much as possible from the running Julia session without reading all the package source. Despite these tweaks, some (like `review-api`) will still burn through a lot of credits.

As of the time of this writing (late April 2026), this repo is still under heavy development.
