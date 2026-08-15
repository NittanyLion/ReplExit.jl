# ReplExit.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://NittanyLion.github.io/ReplExit.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://NittanyLion.github.io/ReplExit.jl/dev/)
[![Build Status](https://github.com/NittanyLion/ReplExit.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/NittanyLion/ReplExit.jl/actions/workflows/CI.yml?query=branch%3Amain)

Type `exit` at the Julia REPL — no parentheses — and the session quits.

```
julia> exit
$
```

`quit` works the same way.

## Installation

```julia
julia> ]
pkg> add ReplExit
```

Then, from a REPL:

```julia
julia> using ReplExit           # bare `exit` works from here on

julia> ReplExit.install()       # and in every future session
```

`install()` adds a marker-delimited block to `~/.julia/config/startup.jl`:

```julia
# >>> ReplExit >>>
try
    using ReplExit             # a bare `exit` (no parentheses) quits the REPL
catch err
    @warn "ReplExit failed to load; run `] add ReplExit` or `] rm` this block" err
end
# <<< ReplExit <<<
```

It is re-runnable — the block is replaced rather than duplicated — leaves the
rest of `startup.jl` alone, and copies the previous contents to
`startup.jl.bak`. The package has to live in the default environment (`]
activate` with no argument, then `] add ReplExit`) for `startup.jl` to find it;
`install()` warns if it does not.

To unwire it again:

```julia
julia> ReplExit.uninstall()
```

If you have been using a hand-rolled `startup.jl` hook for this, take it out
before installing, or the two will both be registered.

## Usage

Loading the package in an interactive session is all it takes. Within a
session, the rewrite can be turned off and back on:

```julia
julia> ReplExit.disable!()      # `exit` on its own is just a function again
true

julia> ReplExit.enable!()
true

julia> ReplExit.isenabled()
true
```

Setting the environment variable `JULIA_REPLEXIT_AUTOENABLE=false` keeps loading
the package from enabling anything, leaving `ReplExit.enable!()` to you.

## How it works

The REPL passes every parsed input through a list of AST transforms before
evaluating it. Typing `exit` arrives as `Expr(:toplevel, LineNumberNode,
:exit)`, so [`ReplExit.transform`](https://NittanyLion.github.io/ReplExit.jl/stable/)
swaps that trailing bare symbol for a call to `exit()`. Anything else passes
through untouched.

`exit` therefore remains an ordinary function value everywhere else — `f =
exit`, `map(f, [exit])`, `exit` inside a script or an `include`d file all behave
exactly as before. Only a line at the REPL consisting of nothing but `exit` (or
`quit`) is rewritten.

The widely posted alternative,

```julia
Base.show(io::IO, ::MIME"text/plain", ::typeof(exit)) = exit()
```

is type piracy: it quits whenever that function object happens to get displayed,
not only when you asked to leave.

## Caveats

- `Base.active_repl_backend` and `REPL.repl_ast_transforms` are Julia internals,
  not public API. Tested on Julia 1.10 and up, against a real REPL driven over a
  pseudo-terminal. If a future release renames them, `enable!` warns and does
  nothing rather than breaking your REPL.
- REPL only. It has no effect on `julia script.jl`.
- Loading the package from `startup.jl` registers the transform before the REPL
  backend exists, by adding it to the list of defaults that the backend is
  created from.
