```@meta
CurrentModule = ReplExit
```

# Installation

Installing ReplExit so that it works in every session takes two steps: add the
package to the *default environment*, then let [`ReplExit.install`](@ref) wire
it into `startup.jl`.

## Step 1: add the package to the default environment

Start `julia` with no `--project` flag and press `]` to enter the package
manager. The prompt shows which environment is active:

```
(@v1.11) pkg>
```

`@v1.11` (or whatever your Julia version is) is the default environment. If the
prompt shows something else, such as `(MyProject) pkg>`, type `activate` with
no arguments to switch back. Then add the package:

```
(@v1.11) pkg> add ReplExit
```

!!! warning "Why the default environment"
    `startup.jl` runs before any project is activated, so `using ReplExit` in
    it can only find packages in the default environment. A ReplExit that is
    installed only in a project environment will load fine when that project
    is active and fail with a warning at every other startup. `install` warns
    if it detects this; take the warning seriously.

## Step 2: wire it into `startup.jl`

In the same session:

```julia
julia> using ReplExit

julia> ReplExit.install()
[ Info: ReplExit: wired `using ReplExit` into /home/you/.julia/config/startup.jl. Takes effect in new sessions.
```

`using ReplExit` enables bare `exit` for the current session right away;
`install` takes care of all future ones.

### What `install` writes

`install` appends this block to `~/.julia/config/startup.jl`, creating the file
and the `config` directory if they do not exist:

```julia
# >>> ReplExit >>>
try
    using ReplExit             # a bare `exit` (no parentheses) quits the REPL
catch err
    @warn "ReplExit failed to load; run `] add ReplExit` or `] rm` this block" err
end
# <<< ReplExit <<<
```

A few properties worth knowing:

- **Re-runnable.** If the block is already there, it is replaced, not
  duplicated. Running `install` twice leaves one block.
- **Surgical.** Everything outside the two marker lines is left exactly as it
  was: your `using Revise`, your `ENV` settings, your prompt customization.
- **Backed up.** Before writing, the previous `startup.jl` is copied to
  `startup.jl.bak` (pass `backup = false` to skip this).
- **Harmless when broken.** The `try` means that if ReplExit is ever removed
  or fails to load, Julia still starts; you see a warning instead of a dead
  REPL.

The exact path can be found with [`ReplExit.startup_file`](@ref), and you can
pass a different path to `install` if you keep your startup file elsewhere:

```julia
julia> ReplExit.install("/path/to/my/startup.jl")
```

### Other depots and `JULIA_DEPOT_PATH`

`install` writes to the `config` directory of the *first* entry in
`DEPOT_PATH`, which is `~/.julia` unless you have set `JULIA_DEPOT_PATH`. That
is also where Julia looks for `startup.jl`, so the two always agree.

## Checking that it worked

Open a fresh `julia` and ask:

```julia
julia> ReplExit.isenabled()
true

julia> exit
$
```

If `isenabled()` is `false` or `ReplExit` is not defined, see
[Troubleshooting](@ref).

## Uninstalling

Take the block out of `startup.jl`, then remove the package:

```julia
julia> ReplExit.uninstall()
[ Info: ReplExit: removed the ReplExit block from /home/you/.julia/config/startup.jl.

julia> ] rm ReplExit
```

`uninstall` is as careful as `install`: it removes only the marker-delimited
block, leaves the rest of the file untouched, backs up first, and does nothing
(with a message) if there is no block to remove.

## If you already had a hand-rolled hook

If your `startup.jl` already contains something that makes bare `exit` work,
such as the `Base.show` type-piracy hack or your own AST transform, remove it
before running `install`. Otherwise both will be active, and the other one may
fire in situations where ReplExit deliberately does not.
