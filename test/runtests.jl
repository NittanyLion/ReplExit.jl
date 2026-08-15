using ReplExit
using REPL
using TOML
using Test

# `Pkg.test` is not interactive, so loading the package did not auto-enable
# anything and every test below starts from a known state.
@testset "ReplExit.jl" begin

    @testset "transform" begin
        line = LineNumberNode(1, :REPL)

        @test ReplExit.transform(Expr(:toplevel, line, :exit)) ==
              Expr(:toplevel, line, :(exit()))
        @test ReplExit.transform(Expr(:toplevel, line, :quit)) ==
              Expr(:toplevel, line, :(exit()))
        @test ReplExit.transform(:exit) == :(exit())
        @test ReplExit.transform(:quit) == :(exit())

        # Everything else goes through untouched.
        for ast in (Expr(:toplevel, line, :(exit())),
                    Expr(:toplevel, line, :(f = exit)),
                    Expr(:toplevel, line, :(map(f, [exit]))),
                    Expr(:toplevel, line, :(1 + 1)),
                    Expr(:toplevel, line, :exit, :(1 + 1)),   # exit is not last
                    Expr(:block, :exit),                      # not top level
                    Expr(:toplevel),
                    :x,
                    42,
                    "exit")
            @test ReplExit.transform(ast) === ast
        end

        # Preceding top-level expressions survive; only the last one is rewritten.
        @test ReplExit.transform(Expr(:toplevel, line, :(x = 1), :exit)) ==
              Expr(:toplevel, line, :(x = 1), :(exit()))
    end

    @testset "enable! / disable! / isenabled" begin
        transforms = ReplExit.ast_transforms()
        @test transforms !== nothing
        @test transforms === REPL.repl_ast_transforms   # no REPL backend in this process
        saved = copy(transforms)
        try
            @test !ReplExit.isenabled()
            @test ReplExit.enable!()
            @test ReplExit.isenabled()
            @test last(transforms) === ReplExit.transform
            @test !ReplExit.enable!()                   # idempotent
            @test count(t -> t === ReplExit.transform, transforms) == 1
            @test ReplExit.disable!()
            @test !ReplExit.isenabled()
            @test !ReplExit.disable!()
            @test transforms == saved                   # the defaults are intact
        finally
            empty!(transforms)
            append!(transforms, saved)
        end
    end

    @testset "startup.jl wiring" begin
        mktempdir() do dir
            startup = joinpath(dir, "startup.jl")

            # Installing into a fresh file.
            @test ReplExit.install(startup) == startup
            first_write = read(startup, String)
            @test occursin(ReplExit.BEGIN_MARKER, first_write)
            @test occursin("using ReplExit", first_write)
            @test !isfile(startup * ".bak")              # nothing to back up yet

            # Re-running replaces the block instead of duplicating it, and backs up.
            @test ReplExit.install(startup) == startup
            @test read(startup, String) == first_write
            @test count(ReplExit.BEGIN_MARKER, read(startup, String)) == 1
            @test isfile(startup * ".bak")

            # Uninstalling puts the file back the way it was.
            @test ReplExit.uninstall(startup) == startup
            @test !occursin("ReplExit", read(startup, String))

            # Surrounding content is preserved on the way in and on the way out.
            mine = "using Revise\nENV[\"EDITOR\"] = \"vim\"\n"
            write(startup, mine)
            ReplExit.install(startup)
            @test occursin(mine, read(startup, String))
            @test read(startup * ".bak", String) == mine
            ReplExit.uninstall(startup)
            @test read(startup, String) == mine

            # Uninstalling twice is a no-op, and so is uninstalling from nothing.
            @test read(ReplExit.uninstall(startup), String) == mine
            missing_file = joinpath(dir, "does-not-exist.jl")
            @test ReplExit.uninstall(missing_file) == missing_file
            @test !isfile(missing_file)
        end

        # `install` creates the config directory if it has to.
        mktempdir() do dir
            startup = joinpath(dir, "config", "startup.jl")
            ReplExit.install(startup; backup = false)
            @test isfile(startup)
        end
    end

    @testset "strip_block" begin
        block = ReplExit.STARTUP_BLOCK
        @test ReplExit.strip_block("a\n" * block * "b\n") == "a\nb\n"
        @test ReplExit.strip_block("a\nb\n") == "a\nb\n"
        # A begin marker with no end marker takes only itself out.
        @test ReplExit.strip_block("a\n$(ReplExit.BEGIN_MARKER)\nb\n") == "a\nb\n"
    end

    @testset "package metadata" begin
        project = TOML.parsefile(joinpath(pkgdir(ReplExit), "Project.toml"))
        @test project["uuid"] == ReplExit.UUID
        @test project["name"] == "ReplExit"
        # `config_dir` and `startup_file` point where the docs say they do.
        @test ReplExit.config_dir() == joinpath(first(DEPOT_PATH), "config")
        @test ReplExit.startup_file() == joinpath(ReplExit.config_dir(), "startup.jl")
        @test ReplExit.in_default_environment() isa Bool
    end

    # The real thing: drive an actual REPL over a pseudo-terminal and check that
    # typing `exit` quits it.  Julia only starts a REPL backend — and hence only
    # applies the AST transforms — when stdin is a TTY, so a pipe will not do.
    @testset "live REPL" begin
        if !Sys.isunix()
            @info "skipping the live REPL test: it needs a Unix pseudo-terminal"
        else
            include("FakePTYs.jl")

            julia = Base.julia_cmd()
            project = something(Base.active_project(), pkgdir(ReplExit))
            cmd = `$julia --startup-file=no --history-file=no --color=no
                   --project=$project -i -e "using ReplExit"`

            pts, ptm = FakePTYs.open_fake_pty()
            output = UInt8[]
            outputlock = ReentrantLock()
            seen(needle) = occursin(needle, lock(() -> String(copy(output)), outputlock))
            waitfor(f; timeout = 120.0) = timedwait(f, timeout; pollint = 0.1) === :ok

            proc = run(cmd, pts, pts, pts; wait = false)
            Base.close_stdio(pts)
            reader = @async try
                while !eof(ptm)
                    chunk = readavailable(ptm)
                    lock(() -> append!(output, chunk), outputlock)
                end
            catch          # the pty errors out when the child goes away; that is fine
            end

            try
                @test waitfor(() -> seen("julia>"))                    # REPL is up

                # An ordinary line still evaluates.  The strings are assembled at
                # run time so that the pty's echo of what we typed cannot be
                # mistaken for the REPL's answer.
                write(ptm, "println(string(\"AL\", \"IVE\"))\n")
                @test waitfor(() -> seen("ALIVE"))
                @test process_running(proc)

                # `exit` used as a value is still just a function.
                write(ptm, "f = exit; println(string(\"NOT\", \"QUIT\"))\n")
                @test waitfor(() -> seen("NOTQUIT"))
                @test process_running(proc)

                # And a bare `exit` quits.
                write(ptm, "exit\n")
                @test waitfor(() -> !process_running(proc))
                @test success(proc)
            finally
                process_running(proc) && kill(proc)
                close(ptm)
                wait(reader)
            end
        end
    end
end
