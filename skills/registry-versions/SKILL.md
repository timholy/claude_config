---
description: List the registered versions of a Julia package via Pkg's registry API (not a directory grep)
argument-hint: "[package name | UUID | path] (defaults to the current project)"
---

Report which versions of a Julia package are registered, across every reachable
registry. The argument (`$ARGUMENTS`) may be a package name, a UUID, or a path to a
package directory; if omitted, use the package in the current directory (read its
`name`/`uuid` from `Project.toml`).

Common uses: deciding whether renaming/removing a public symbol is breaking (is the
symbol in a *registered* release, or only on an unreleased `main`?), and checking the
latest registered version before a release.

## Do not grep the registry directory

`~/.julia/registries/General` is stored as a **compressed tarball** (`General.tar.gz`),
so `find`/`grep` over the registries directory silently finds nothing even for a package
that *is* registered — a false negative. Query through Pkg, which reads the tarball
natively. (A private registry like `HolyLabRegistry` may be an unpacked directory, but
use the same Pkg path uniformly so the answer never depends on the storage format.)

## Query

Resolve the target to a UUID when you can — a UUID match avoids false hits from
similarly-named packages. Then:

```julia
using Pkg
using Pkg.Registry: reachable_registries, registry_info

target = "PenalizedDensity"   # a name, or a UUID string; from $ARGUMENTS or Project.toml
found = false
for reg in reachable_registries()
    for (uuid, e) in reg.pkgs
        (e.name == target || string(uuid) == target) || continue
        info = registry_info(e)
        vers = sort(collect(keys(info.version_info)))
        println(reg.name, ": ", e.name, " [", uuid, "]  versions = ", vers)
        global found = true
    end
end
found || println("not registered in any reachable registry")
```

This is a one-shot query with no need for Revise, so running `julia` directly from the
shell is fine.

## Report

State the registry (or registries) the package appears in and the sorted version list,
and — when the caller is weighing a breaking change — whether the symbol in question
predates or postdates the latest *registered* version, since only registered releases
constrain compatibility. If the package is not in any reachable registry, say so plainly:
that means nothing has shipped through a registry, whatever git tags exist locally.
