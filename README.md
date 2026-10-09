# ReplExit.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://NittanyLion.github.io/ReplExit.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://NittanyLion.github.io/ReplExit.jl/dev/)
[![Build Status](https://github.com/NittanyLion/ReplExit.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/NittanyLion/ReplExit.jl/actions/workflows/CI.yml?query=branch%3Amain)
![authored by: JP](authored_by.svg)

Type `exit` at the Julia REPL — no parentheses — and the session quits.

```
julia> exit
$
```

`quit` works the same way. Everywhere else, `exit` is still the ordinary
function it always was: only a REPL line consisting of nothing but `exit` or
`quit` is affected.

## Installation

Two steps: add the package to your **default environment**, then wire it into
`startup.jl` so that it loads itself every time Julia starts.

### 1. Add the package

Start `julia` with no `--project` flag, so that the package manager is in the
default environment (the prompt shows `(@v1.11) pkg>` or similar, not a
project name), and run

```julia
julia> ]
(@v1.11) pkg> add ReplExit
```

If the prompt shows something other than `(@v1.x)`, type `activate` with no
argument first to get back to the default environment. The default environment
is the only one `startup.jl` can load from, so this is where the package has to
live.

### 2. Wire it into `startup.jl`

```julia
julia> using ReplExit           # bare `exit` works from here on

julia> ReplExit.install()       # and in every future session
```

That is all. From the next Julia session on, `exit` on its own quits.

`install()` adds this block to `~/.julia/config/startup.jl`, creating the file
and directory if they do not exist:

```julia
# >>> ReplExit >>>
try
    using ReplExit             # a bare `exit` (no parentheses) quits the REPL
catch err
    @warn "ReplExit failed to load; run `] add ReplExit` or `] rm` this block" err
end
# <<< ReplExit <<<
```

It is safe to run again: the block is replaced, never duplicated, the rest of
`startup.jl` is left exactly as it was, and the previous contents are copied to
`startup.jl.bak` first. The `try` means that a missing or broken ReplExit can
never keep Julia from starting; you get a warning instead.

`install()` warns if the package is not in the default environment. Heed that
warning: `startup.jl` runs before any project is activated, so a ReplExit that
lives only in some project environment will not be found.

### Checking that it worked

Open a fresh `julia`, and the first line should print `true`:

```julia
julia> ReplExit.isenabled()
true

julia> exit
$
```

### Uninstalling

```julia
julia> ReplExit.uninstall()     # takes the block out of startup.jl again
julia> ] rm ReplExit            # and removes the package
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
:exit)`, so `ReplExit.transform` swaps that trailing bare symbol for a call to
`exit()`. Anything else passes through untouched.

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

The [manual](https://NittanyLion.github.io/ReplExit.jl/stable/) has the
details, a troubleshooting page, and the full API reference.

## Caveats

- `Base.active_repl_backend` and `REPL.repl_ast_transforms` are Julia internals,
  not public API. Tested on Julia 1.10 and up, against a real REPL driven over a
  pseudo-terminal. If a future release renames them, `enable!` warns and does
  nothing rather than breaking your REPL.
- REPL only. It has no effect on `julia script.jl`, on `julia -e`, or on code
  evaluated by an editor or notebook that does not go through the REPL's AST
  transforms.
- Loading the package from `startup.jl` registers the transform before the REPL
  backend exists, by adding it to the list of defaults that the backend is
  created from.

## License

MIT; see [LICENSE](LICENSE).
