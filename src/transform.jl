# The rewrite itself, and its registration with the REPL.
#
# The REPL runs every parsed input through a list of AST transforms before
# evaluating it.  Input arrives wrapped as
#
#     Expr(:toplevel, LineNumberNode, :exit)
#
# so `transform` swaps a trailing bare `exit`/`quit` symbol for a call to
# `exit()`.  Everything else passes through untouched.
#
# Compare the popular one-liner
#
#     Base.show(io::IO, ::MIME"text/plain", ::typeof(exit)) = exit()
#
# which is type piracy and fires whenever that object happens to be displayed.

"""
    ReplExit.UUID

The package's UUID, as written in its `Project.toml`.
"""
const UUID = "9f306d03-dd66-4e92-980c-0d66fd852725"

"""
    ReplExit.transform(ast)

Rewrite a REPL input `ast` whose last top-level expression is a bare `exit` or
`quit` symbol into the same AST with `exit()` called instead. Any other input is
returned unchanged.

This is the function that [`ReplExit.enable!`](@ref) appends to the REPL's list
of AST transforms.

# Examples
```jldoctest
julia> ReplExit.transform(Expr(:toplevel, :exit)) == Expr(:toplevel, :(exit()))
true

julia> ReplExit.transform(Expr(:toplevel, :(f = exit))) == Expr(:toplevel, :(f = exit))
true
```
"""
function transform(ast)
    if ast === :exit || ast === :quit
        return :(exit())
    elseif ast isa Expr && ast.head === :toplevel && !isempty(ast.args) &&
           (ast.args[end] === :exit || ast.args[end] === :quit)
        return Expr(:toplevel, ast.args[1:end-1]..., :(exit()))
    end
    return ast
end

"""
    ReplExit.ast_transforms() -> Union{Vector,Nothing}

The list of AST transforms that a REPL line currently goes through: the running
backend's own list if there is one, and otherwise the list of defaults that new
backends are created with. Returns `nothing` if neither can be found, which is
what happens if a future Julia release renames these internals.
"""
function ast_transforms()
    backend = isdefined(Base, :active_repl_backend) ? Base.active_repl_backend : nothing
    if backend !== nothing && hasproperty(backend, :ast_transforms)
        return backend.ast_transforms
    elseif isdefined(REPL, :repl_ast_transforms)
        return REPL.repl_ast_transforms
    end
    return nothing
end

# Every list [`transform`](@ref) may have been registered with: the running
# backend got a *copy* of the defaults, so disabling has to reach both.
function all_ast_transforms()
    lists = Any[]
    backend = isdefined(Base, :active_repl_backend) ? Base.active_repl_backend : nothing
    if backend !== nothing && hasproperty(backend, :ast_transforms)
        push!(lists, backend.ast_transforms)
    end
    isdefined(REPL, :repl_ast_transforms) && push!(lists, REPL.repl_ast_transforms)
    return lists
end

"""
    ReplExit.enable!() -> Bool

Register [`ReplExit.transform`](@ref) with the REPL, so that a bare `exit` or
`quit` quits Julia. Returns `true` if that changed anything: it is a no-op when
the transform is already registered, and returns `false` (with a warning) if the
REPL internals it needs are not there.

Called automatically when the package is loaded in an interactive session,
unless the environment variable `JULIA_REPLEXIT_AUTOENABLE` is set to `"false"`.

Registering before the REPL backend exists — from `startup.jl`, say — works
fine: the transform goes into the list of defaults that the backend is then
created from.
"""
function enable!()
    transforms = ast_transforms()
    if transforms === nothing
        @warn "ReplExit: this Julia does not expose the REPL AST transforms; bare `exit` not enabled"
        return false
    end
    any(t -> t === transform, transforms) && return false
    push!(transforms, transform)
    return true
end

"""
    ReplExit.disable!() -> Bool

Undo [`ReplExit.enable!`](@ref): `exit` and `quit` on their own go back to
showing the function rather than quitting. Returns `true` if the transform was
registered and has been removed.
"""
function disable!()
    removed = false
    for transforms in all_ast_transforms()
        n = length(transforms)
        filter!(t -> t !== transform, transforms)
        removed |= length(transforms) < n
    end
    return removed
end

"""
    ReplExit.isenabled() -> Bool

Whether a bare `exit` at the REPL currently quits Julia.
"""
function isenabled()
    transforms = ast_transforms()
    return transforms !== nothing && any(t -> t === transform, transforms)
end
