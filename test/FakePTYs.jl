# Vendored from Julia's own test helpers (test/testhelpers/FakePTYs.jl), MIT
# licensed like Julia itself, cut down to the Unix path: the live-REPL test
# needs a terminal, because Julia only runs the REPL backend — and hence the AST
# transforms — when stdin is a TTY.
module FakePTYs

function open_fake_pty()
    Sys.isunix() || error("FakePTYs: Unix only")

    O_RDWR = Base.Filesystem.JL_O_RDWR
    O_NOCTTY = Base.Filesystem.JL_O_NOCTTY

    fdm = ccall(:posix_openpt, Cint, (Cint,), O_RDWR | O_NOCTTY)
    fdm == -1 && error("Failed to open ptm")
    rc = ccall(:grantpt, Cint, (Cint,), fdm)
    rc != 0 && error("grantpt failed")
    rc = ccall(:unlockpt, Cint, (Cint,), fdm)
    rc != 0 && error("unlockpt failed")

    fds = ccall(:open, Cint, (Ptr{UInt8}, Cint, UInt32...),
                ccall(:ptsname, Ptr{UInt8}, (Cint,), fdm), O_RDWR | O_NOCTTY)
    pts = RawFD(fds)
    ptm = Base.TTY(RawFD(fdm))
    return pts, ptm
end

end # module
