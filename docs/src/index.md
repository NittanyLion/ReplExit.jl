```@meta
CurrentModule = ReplExit
```

# ReplExit.jl

Type `exit` at the Julia REPL — no parentheses — and the session quits.

```
julia> exit
$
```

`quit` works the same way.

Everywhere else, `exit` is still the ordinary function it always was. Only a
REPL line consisting of nothing but `exit` or `quit` is affected: `f = exit`
still assigns the function, `exit` inside a script still shows it, and
`exit(1)` still exits with status 1 as it always did.

## Quick start

Add the package to the default environment and wire it into `startup.jl`:

```julia
julia> ]
(@v1.11) pkg> add ReplExit

julia> using ReplExit           # bare `exit` works from here on

julia> ReplExit.install()       # and in every future session
```

From the next Julia session on, `exit` on its own quits. The
[Installation](@ref) page explains what `install` writes, why the package has
to be in the default environment, and how to undo it all.

## Why a package for this

The one-liner that circulates for this purpose,

```julia
Base.show(io::IO, ::MIME"text/plain", ::typeof(exit)) = exit()
```

is type piracy. It quits Julia whenever the `exit` function happens to get
displayed, which is not only when you typed `exit` at the prompt: it fires on
`f = exit` (the REPL shows the result), on a vector containing `exit`, and on
any `@show` or `display` that reaches it. ReplExit instead hooks into the
REPL's own input pipeline, so it sees exactly what you typed and leaves the
`exit` function alone. [How it works](@ref) has the details.

## Contents

```@contents
Pages = ["installation.md", "usage.md", "internals.md", "troubleshooting.md", "reference.md"]
Depth = 2
```
