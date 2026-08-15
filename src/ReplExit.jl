"""
    ReplExit

Type `exit` at the Julia REPL — no parentheses — and the session quits. `quit`
works the same way.

```
julia> exit
\$
```

Loading the package with `using ReplExit` from an interactive session (or from
`~/.julia/config/startup.jl`) is all it takes; see [`ReplExit.install`](@ref)
for wiring up `startup.jl`, and [`ReplExit.enable!`](@ref) /
[`ReplExit.disable!`](@ref) for turning the rewrite on and off by hand.

Only a REPL line consisting of nothing but `exit` (or `quit`) is rewritten;
`exit` remains an ordinary function value everywhere else.
"""
module ReplExit

using REPL

include("transform.jl")
include("startup.jl")

function __init__()
    if isinteractive() && get(ENV, "JULIA_REPLEXIT_AUTOENABLE", "true") != "false"
        try
            enable!()
        catch err
            # Never take the REPL down with us: this may well run from startup.jl.
            @warn "ReplExit: could not enable bare `exit`" exception = (err, catch_backtrace())
        end
    end
    return nothing
end

end # module
