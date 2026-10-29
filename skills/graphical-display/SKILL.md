---
description: Choose between an interactive window and headless output before a Julia session loads any plotting or GUI package (GLMakie, CairoMakie, WGLMakie, Plots, Gtk, Qt, ProfileView, ...). Covers checking `DISPLAY`, using the inherited monitor (e.g., WSLg), and when to start Xvfb or use `xvfb-run`. Read this BEFORE the first `using` of any such package. Also use it when the user asks for a plot, figure, or window, when a package's tests or `Pkg.test()` need a display, or when a figure fails to appear. Choosing wrong usually means restarting the session and losing its loaded state.
---

# Graphical display (Makie, Gtk, Qt, …)

Decide **at session start**, before loading any plotting backend, whether the
work is interactive or headless. Switching later requires reloading the
backend, and restarting the session to switch discards accumulated state
(loaded packages, data, open figures). If a backend is already loaded in the
wrong mode, tell the user and ask before restarting.

Check what's available first:

    get(ENV, "DISPLAY", "")   # ":0" => a real monitor is available (e.g. WSLg)

- **Interactive (default for analysis/exploration).** When a real display is
  present, the MCP session inherits it automatically — do *not* override
  `DISPLAY`:

      using GLMakie; GLMakie.activate!()
      display(fig)   # live window on the monitor; persists/updates across eval calls

- **Headless (CI-like batch, final `Pkg.test()`, profiling, or no real
  display).** Either render to files with a non-interactive backend
  (CairoMakie → PNG/SVG), or start a virtual display once and point the session
  at it *before* loading the backend:

      # Bash: Xvfb :99 -screen 0 1024x768x24 &
      ENV["DISPLAY"] = ":99"

  Fall back to `xvfb-run julia ...` via Bash only for final `Pkg.test()` runs or
  when the MCP session cannot be reconfigured.

Only spin up Xvfb when no real display is present or you explicitly want
headless output — on a desktop session the inherited `:0` already shows
figures on the monitor.
