```@meta
CurrentModule = ReplExit
```

# Usage

Once the package is loaded in an interactive session, there is nothing to
call. Type `exit` or `quit` on a line of its own and Julia quits with exit
status 0, exactly as `exit()` would.

```
julia> exit
$
```

Everything else about `exit` is unchanged:

```julia
julia> exit(3)            # quits with status 3, as always

julia> f = exit           # assigns the function; does not quit
exit (generic function with 2 methods)

julia> [exit, exit]       # displays a vector; does not quit
2-element Vector{typeof(exit)}:
 exit (generic function with 2 methods)
 exit (generic function with 2 methods)

julia> x = 1; exit        # quits: `exit` is the last expression on the line
```

The last example shows the rule precisely: the *final* top-level expression on
a REPL line being a bare `exit` or `quit` is what triggers the rewrite. An
`exit` earlier on the line, as in `exit; x = 1`, is left alone and simply
shows the function.

## Turning it off and on within a session

The rewrite can be removed and put back at any time:

```julia
julia> ReplExit.disable!()      # `exit` on its own shows the function again
true

julia> exit
exit (generic function with 2 methods)

julia> ReplExit.enable!()
true

julia> ReplExit.isenabled()
true
```

All three return a `Bool`. [`ReplExit.enable!`](@ref) and
[`ReplExit.disable!`](@ref) return whether they changed anything, so calling
`enable!` twice returns `true` then `false`. [`ReplExit.isenabled`](@ref)
reports the current state.

## Loading without enabling

By default, `using ReplExit` in an interactive session enables the rewrite
immediately. To load the package without that side effect, set the environment
variable `JULIA_REPLEXIT_AUTOENABLE` to `false` before starting Julia:

```sh
JULIA_REPLEXIT_AUTOENABLE=false julia
```

The package then does nothing until you call `ReplExit.enable!()` yourself.
Any value other than the string `false` leaves auto-enabling on.

Non-interactive sessions (`julia script.jl`, `julia -e`, `Pkg.test`) never
auto-enable, with or without the variable: there is no REPL there to attach
to.

## Where it applies

ReplExit acts on the REPL's input pipeline, so it affects:

- the standard Julia REPL in a terminal;
- the REPL inside an editor or IDE that drives a real Julia REPL, such as the
  integrated terminal in VS Code.

It does not affect:

- scripts run with `julia script.jl` or `julia -e`;
- code `include`d from the REPL (that goes through `include`, not through the
  REPL's transforms);
- notebooks and other front ends that evaluate code by other means. In those,
  `exit` on its own just shows the function, as it did before.
