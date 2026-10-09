```@meta
CurrentModule = ReplExit
DocTestSetup = :(using ReplExit)
```

# How it works

ReplExit is one function registered in one list. This page explains the list,
the function, and the two situations in which the registration happens.

## The REPL's AST transforms

When you press Enter at the `julia>` prompt, the REPL parses the line into an
expression and, before evaluating it, passes that expression through every
function in the REPL backend's `ast_transforms` list, in order. Julia itself
uses this mechanism: `REPL.softscope`, which gives top-level assignments at the
prompt the "soft scope" rules that scripts do not have, is one of the
transforms every REPL starts with.

A typed line arrives wrapped as a top-level expression with a line number:

```julia
Expr(:toplevel, LineNumberNode(1, :REPL), :exit)
```

The bare word `exit` is the symbol `:exit`, the last argument of that `Expr`.

## The transform

[`ReplExit.transform`](@ref) inspects the expression it is handed. If it is a
`:toplevel` expression whose last argument is the symbol `:exit` or `:quit`,
it returns the same expression with that last argument replaced by the call
`:(exit())`. A bare symbol on its own (which some REPL modes hand through
without the `:toplevel` wrapper) is treated the same way. Anything else comes
back untouched, by identity.

```jldoctest
julia> ReplExit.transform(Expr(:toplevel, :exit)) == Expr(:toplevel, :(exit()))
true

julia> ast = Expr(:toplevel, :(f = exit));

julia> ReplExit.transform(ast) === ast
true
```

The check is deliberately narrow. `f = exit` is an `Expr(:(=), ...)`, not the
symbol `:exit`, so it passes through. `exit` inside a `begin` block is nested
inside an `Expr(:block, ...)`, so it passes through. `exit; x = 1` has `:exit`
as the first argument and `:(x = 1)` as the last, so it passes through. Only
the exact shape "last top-level thing on the line is the bare word" is
rewritten, and that is the shape that means "I typed `exit` and pressed
Enter".

Because the function `exit` itself is never touched, there is no type piracy
and no method redefinition. `ReplExit` adds nothing to `Base`.

## Registering it

[`ReplExit.enable!`](@ref) pushes `transform` onto the end of the active
transform list. Which list that is depends on when `enable!` runs.

**From a running REPL.** Once the REPL is up, `Base.active_repl_backend` holds
the backend, and `backend.ast_transforms` is the live list. `enable!` appends
to it, and the next line you type goes through `transform`.

**From `startup.jl`.** `startup.jl` runs before the REPL backend is created,
so `Base.active_repl_backend` is not yet defined. In that case `enable!` falls
back to `REPL.repl_ast_transforms`, the list of *defaults* from which every
new backend copies its own list. The backend that is created a moment later
starts with `transform` already in it. This is why `using ReplExit` in
`startup.jl` is all the wiring that is needed.

[`ReplExit.disable!`](@ref) removes `transform` from both lists, because after
startup it may be in both: the backend's copy and the defaults it was copied
from. [`ReplExit.isenabled`](@ref) checks whichever list a typed line would
currently go through.

[`ReplExit.ast_transforms`](@ref) returns that list, or `nothing` if neither
`Base.active_repl_backend` nor `REPL.repl_ast_transforms` exists.

## Auto-enabling on load

The module's `__init__` calls `enable!` when `isinteractive()` is true and the
environment variable `JULIA_REPLEXIT_AUTOENABLE` is not `"false"`. Any error
is caught and reported as a warning rather than thrown, because `__init__` may
be running from `startup.jl`, and an exception there would spoil every Julia
session the user starts.

## On relying on internals

`Base.active_repl_backend`, `REPL.REPLBackend.ast_transforms` and
`REPL.repl_ast_transforms` are not documented API. They have been stable from
Julia 1.5 through 1.13 and the package is tested on 1.10 and up, including a
test that drives a real REPL over a pseudo-terminal and types `exit` at it.
Every access to them is guarded with `isdefined` or `hasproperty`, so if a
future Julia renames them the result is a warning from `enable!` and an
unchanged REPL, not a crash.
