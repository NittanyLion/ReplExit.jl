```@meta
CurrentModule = ReplExit
```

# ReplExit

Documentation for [ReplExit](https://github.com/NittanyLion/ReplExit.jl).

Type `exit` at the Julia REPL — no parentheses — and the session quits. `quit`
works the same way.

```julia
julia> using ReplExit           # bare `exit` works from here on

julia> ReplExit.install()       # and in every future session
```

See the [README](https://github.com/NittanyLion/ReplExit.jl) for what the
rewrite does and does not touch.

## Index

```@index
```

## Reference

```@autodocs
Modules = [ReplExit]
```
