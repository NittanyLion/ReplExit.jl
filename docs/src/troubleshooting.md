```@meta
CurrentModule = ReplExit
```

# Troubleshooting

Each entry gives a symptom, the usual cause, and the fix.

## `exit` shows the function instead of quitting

```
julia> exit
exit (generic function with 2 methods)
```

**The package is not loaded or not enabled.** Check:

```julia
julia> ReplExit.isenabled()
```

- `UndefVarError: ReplExit not defined`: the package was not loaded in this
  session. Run `using ReplExit`, and run [`ReplExit.install`](@ref) if you
  want that to happen automatically; see [Installation](@ref).
- `false`: the package is loaded but the transform is not registered. Either
  `JULIA_REPLEXIT_AUTOENABLE` is set to `false` in your environment, or
  [`ReplExit.disable!`](@ref) was called. `ReplExit.enable!()` puts it back.
- `true`, yet `exit` still shows the function: you are not typing into the
  standard REPL. Notebooks and some editor integrations evaluate code without
  going through the REPL's AST transforms. See [Where it applies](@ref).

## A warning at startup: "ReplExit failed to load"

```
┌ Warning: ReplExit failed to load; run `] add ReplExit` or `] rm` this block
```

**`startup.jl` is trying to load the package, but Julia cannot find it.** The
block that `install` wrote is still there, but the package is not in the
default environment: it was removed, or it was only ever added to a project
environment. Either add it to the default environment

```
julia> ]
(@v1.11) pkg> activate
(@v1.11) pkg> add ReplExit
```

or, if you no longer want it, take the block out with `ReplExit.uninstall()`
(after a one-off `using ReplExit` from wherever it is installed) or by deleting
the lines between `# >>> ReplExit >>>` and `# <<< ReplExit <<<` in
`~/.julia/config/startup.jl` by hand.

## `install` warns that the package is not in the default environment

```
┌ Warning: ReplExit is not installed in the default environment, so `startup.jl` will not find it.
```

**You ran `] add ReplExit` with a project active.** `startup.jl` runs before
any project is activated and can only load from the default environment. Fix
it with:

```
julia> ]
(@v1.11) pkg> activate
(@v1.11) pkg> add ReplExit
```

and then `ReplExit.install()` again. The warning does not stop `install` from
writing the block; it just tells you the block will fail until the package is
where it needs to be.

## "This Julia does not expose the REPL AST transforms"

```
┌ Warning: ReplExit: this Julia does not expose the REPL AST transforms; bare `exit` not enabled
```

**A Julia release has renamed the internals the package depends on.**
`enable!` looked for both `Base.active_repl_backend.ast_transforms` and
`REPL.repl_ast_transforms` and found neither. Nothing is broken; the rewrite
is just not active. Please open an issue with your Julia version so that the
package can be updated.

## It works in one session but not the next

**The package was loaded by hand, not from `startup.jl`.** `using ReplExit`
enables the rewrite for the current session only. Run `ReplExit.install()`
once to make it permanent; see [Installation](@ref).

## It works, but Julia takes longer to start

`using ReplExit` from `startup.jl` costs roughly the time of loading one tiny
precompiled package, a few tens of milliseconds. If startup is noticeably
slower, something else in `startup.jl` is the cause; try starting with
`julia --startup-file=no` to compare.

## Both my old hook and ReplExit are active

If you had a `Base.show(::IO, ::MIME"text/plain", ::typeof(exit)) = exit()`
line or a transform of your own in `startup.jl`, it is still there alongside
the ReplExit block. Delete the old one; `uninstall` only removes what
`install` wrote.

## `startup.jl` got mangled

`install` and `uninstall` both copy the previous file to `startup.jl.bak`
before writing. Copy it back:

```sh
cp ~/.julia/config/startup.jl.bak ~/.julia/config/startup.jl
```

Note that only the most recent backup is kept: a second `install` or
`uninstall` overwrites the `.bak` file.

## I want to disable it for one session

```sh
JULIA_REPLEXIT_AUTOENABLE=false julia
```

leaves the package loaded but dormant; `ReplExit.disable!()` after startup
achieves the same from inside a session.
