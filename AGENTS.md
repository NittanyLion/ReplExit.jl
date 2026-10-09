# AGENTS.md

Guidance for AI coding agents (and new human contributors) working in this
repository. Read it before changing anything.

## What this package is

ReplExit.jl makes a bare `exit` (or `quit`) typed at the Julia REPL quit the
session, by registering one AST transform with the REPL. It is deliberately
tiny: one transform, the functions that register and unregister it, and the
functions that wire `using ReplExit` into `~/.julia/config/startup.jl`.

Keep it that way. Do not add features that are not about leaving the REPL.

## Layout

| Path | What it holds |
|---|---|
| `src/ReplExit.jl` | Module, docstring, `__init__` (auto-enables in interactive sessions) |
| `src/transform.jl` | `transform`, `enable!`, `disable!`, `isenabled`, and the lookup of the REPL's transform lists |
| `src/startup.jl` | `install`, `uninstall`, `strip_block`, and the `startup.jl` block with its markers |
| `test/runtests.jl` | Unit tests plus a live REPL driven over a pseudo-terminal |
| `test/FakePTYs.jl` | Pseudo-terminal helper for the live test (Unix only) |
| `docs/` | Documenter manual; `docs/src/*.md` are the pages, `docs/make.jl` the page order |
| `.github/workflows/` | CI (tests on Linux, macOS, Windows; docs deploy and doctests), CompatHelper, TagBot |

`Manifest.toml` files and `docs/build/` are ignored by git. Do not commit them.

## Design rules

These are the invariants. A change that breaks one of them is wrong even if
the tests pass.

1. **Only a bare `exit` or `quit` at the REPL is rewritten.** The transform
   rewrites a trailing top-level bare symbol and nothing else. `f = exit`,
   `map(f, [exit])`, `exit` inside a block, `exit` in a script, and `exit`
   that is not the last top-level expression on the line must all be left
   alone. There are tests for each of these; keep them passing.
2. **No type piracy.** Never define methods on `Base` types the package does
   not own. In particular, never add the `Base.show(::IO, ::MIME"text/plain",
   ::typeof(exit)) = exit()` hack; the package exists to avoid it.
3. **Never take the REPL down.** The package is loaded from `startup.jl`, so
   anything that throws there breaks every Julia session the user starts.
   `__init__` catches and warns; `enable!` returns `false` with a warning when
   the REPL internals are missing. Preserve this.
4. **`install` and `uninstall` are surgical.** They only touch the text between
   the `# >>> ReplExit >>>` and `# <<< ReplExit <<<` markers, are idempotent,
   and back up the file first. The rest of the user's `startup.jl` is theirs.
5. **The REPL internals are not ours.** `Base.active_repl_backend` and
   `REPL.repl_ast_transforms` are undocumented. Every access goes through
   `isdefined` or `hasproperty` guards and falls back to `nothing`. Do not add
   a direct reference to either.
6. **No new dependencies.** `REPL` is the only dependency and it is a stdlib.

## Building and testing

```sh
julia --project=. -e 'using Pkg; Pkg.test()'        # full test suite
julia --project=docs docs/make.jl                   # build the manual into docs/build/
julia --project=docs -e 'using Documenter, ReplExit; DocMeta.setdocmeta!(ReplExit, :DocTestSetup, :(using ReplExit); recursive=true); doctest(ReplExit)'
```

The first time, instantiate the docs environment with
`julia --project=docs -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate()'`.

Things to know about the tests:

- `Pkg.test` is not interactive, so loading the package in the test process
  does not auto-enable anything. The tests rely on starting from that clean
  state.
- The "live REPL" test set starts a real `julia -i` over a pseudo-terminal and
  types `exit` at it. It needs a Unix PTY and is skipped on Windows. If you
  change `transform` or `enable!`, this is the test that proves the change
  works in a real session; run it.
- Docstring examples are doctests, run in CI. If you change a docstring that
  contains a `jldoctest` block, run the doctest command above.

Always run the full test suite before you report a change as done, and say in
your report whether the live REPL test ran or was skipped.

## Conventions

- American spelling in code, comments, docstrings and documentation.
- Unicode operators where Julia accepts them: `≠`, `≤`, `≥`, `∈`, `∉`, `≡`, `≢`
  rather than `!=`, `<=`, `>=`, `in`, `!(x in y)`, `===`, `!==`. Leave an
  existing line alone unless you are editing it anyway.
- Every public function has a docstring beginning with its signature, and is
  listed in `docs/src/reference.md`. A new public function goes in both places.
- Comments explain why, not what. The source files each open with a comment
  explaining the mechanism they implement; keep those accurate.
- Nothing is exported. Users call `ReplExit.install()`, `ReplExit.enable!()`
  and so on. Do not add `export`.
- Naming: functions that mutate REPL state end in `!` (`enable!`,
  `disable!`); functions that write files do not (`install`, `uninstall`),
  following Julia's convention that `!` marks mutation of an argument or of
  program state, not of the file system.

## Documentation

The README and the manual overlap on purpose: the README is for someone
deciding whether to install, the manual is the full reference. When you change
behavior, update both, plus the docstring. The manual pages are:

- `docs/src/index.md`: what it does, quick start.
- `docs/src/installation.md`: the default environment, `startup.jl`, checking,
  uninstalling.
- `docs/src/usage.md`: enable, disable, environment variable.
- `docs/src/internals.md`: how the transform and the registration work.
- `docs/src/troubleshooting.md`: symptoms and fixes.
- `docs/src/reference.md`: `@docs` blocks for every documented name.

Documenter fails the build on a docstring that is not included in any `@docs`
block when `checkdocs = :all`, so adding a docstring means adding it to
`reference.md` too.

## Versioning and release

- Semantic versioning. Bump `version` in `Project.toml` in the same commit as
  the change that warrants it, or in a separate "Bump version" commit; never
  release without bumping.
- Keep `[compat]` entries for every dependency, including `julia`. The
  minimum Julia is 1.10; do not use syntax or stdlib functions newer than that
  without raising it.
- Releases are made by commenting `@JuliaRegistrator register` on the release
  commit on GitHub. TagBot then tags the release and Documenter deploys the
  `stable` docs. Do not create tags by hand.
- Do not register a release yourself. Registration is the maintainer's call.

## Things not to do

- Do not commit `Manifest.toml`, `docs/Manifest.toml` or `docs/build/`.
- Do not change the package UUID. It is checked against `Project.toml` in the
  tests and is baked into `in_default_environment`.
- Do not touch the user's real `~/.julia/config/startup.jl` from tests;
  always pass an explicit path into `install` and `uninstall` and use
  `mktempdir`.
- Do not widen the transform to catch `exit` in other positions "for
  convenience". Rule 1 above exists because that is exactly how the type
  piracy hack went wrong.
