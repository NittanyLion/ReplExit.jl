# Wiring the package into ~/.julia/config/startup.jl, so that bare `exit` is
# there in every session.  The block is delimited by markers, which is what
# makes `install` re-runnable and `uninstall` surgical: the rest of the file is
# never touched.

const BEGIN_MARKER = "# >>> ReplExit >>>"
const END_MARKER = "# <<< ReplExit <<<"

const STARTUP_BLOCK = """
$BEGIN_MARKER
try
    using ReplExit             # a bare `exit` (no parentheses) quits the REPL
catch err
    @warn "ReplExit failed to load; run `] add ReplExit` or `] rm` this block" err
end
$END_MARKER
"""

"""
    ReplExit.config_dir() -> String

The `config` directory of the first depot on `DEPOT_PATH`, usually
`~/.julia/config`.
"""
config_dir() = joinpath(first(DEPOT_PATH), "config")

"""
    ReplExit.startup_file() -> String

Path of the `startup.jl` that [`ReplExit.install`](@ref) writes to, usually
`~/.julia/config/startup.jl`.
"""
startup_file() = joinpath(config_dir(), "startup.jl")

"""
    ReplExit.install([startup::AbstractString]; backup = true) -> String

Add a marker-delimited `using ReplExit` block to `startup.jl`, so that bare
`exit` works in every new REPL session, and return the path written. Defaults to
[`ReplExit.startup_file`](@ref).

Safe to re-run: an existing block is replaced rather than duplicated, and the
rest of `startup.jl` is left alone. The previous contents are copied to
`startup.jl.bak` unless `backup = false`.

For this to work the package has to be installed in the default environment
(`] activate` nothing, then `] add ReplExit`); `install` warns if it is not.
Takes effect in new sessions. Undo with [`ReplExit.uninstall`](@ref).
"""
function install(startup::AbstractString = startup_file(); backup::Bool = true)
    if startup == startup_file() && !in_default_environment()
        @warn """ReplExit is not installed in the default environment, so `startup.jl` \
                 will not find it. Run `] activate` followed by `] add ReplExit`."""
    end
    mkpath(dirname(startup))
    old = isfile(startup) ? read(startup, String) : ""
    if backup && !isempty(old)
        cp(startup, startup * ".bak"; force = true)
    end
    kept = strip_block(old)
    body = isempty(strip(kept)) ? STARTUP_BLOCK : rstrip(kept) * "\n\n" * STARTUP_BLOCK
    write(startup, body)
    @info "ReplExit: wired `using ReplExit` into $startup. Takes effect in new sessions."
    return startup
end

"""
    ReplExit.uninstall([startup::AbstractString]; backup = true) -> String

Remove the block that [`ReplExit.install`](@ref) added to `startup.jl` and
return the path written, leaving everything else in the file as it was. The
previous contents are copied to `startup.jl.bak` unless `backup = false`.

This only unwires the package; `] rm ReplExit` removes it.
"""
function uninstall(startup::AbstractString = startup_file(); backup::Bool = true)
    isfile(startup) || return startup
    old = read(startup, String)
    kept = strip_block(old)
    if kept == old
        @info "ReplExit: no ReplExit block found in $startup; nothing to do."
        return startup
    end
    backup && cp(startup, startup * ".bak"; force = true)
    write(startup, isempty(strip(kept)) ? "" : rstrip(kept) * "\n")
    @info "ReplExit: removed the ReplExit block from $startup."
    return startup
end

"""
    ReplExit.strip_block(text::AbstractString) -> String

`text` with the marker-delimited `ReplExit` block, if any, taken out. A begin
marker without a matching end marker is dropped on its own rather than eating
the remainder of the file.
"""
function strip_block(text::AbstractString)
    lines = split(text, '\n')
    kept = String[]
    skipping = false
    for (i, line) in pairs(lines)
        stripped = strip(line)
        if stripped == BEGIN_MARKER
            skipping = any(l -> strip(l) == END_MARKER, @view lines[i+1:end])
        elseif stripped == END_MARKER
            skipping = false
        elseif !skipping
            push!(kept, line)
        end
    end
    return join(kept, '\n')
end

"""
    ReplExit.in_default_environment() -> Bool

Whether the package is a dependency of the default (`@v#.#`) environment, which
is what `startup.jl` loads from.
"""
function in_default_environment()
    project = Base.load_path_expand("@v#.#")
    (project === nothing || !isfile(project)) && return false
    return occursin(UUID, read(project, String))
end
