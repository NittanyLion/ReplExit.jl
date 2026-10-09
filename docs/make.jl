using ReplExit
using Documenter

DocMeta.setdocmeta!(ReplExit, :DocTestSetup, :(using ReplExit); recursive=true)

makedocs(;
    modules=[ReplExit],
    authors="Joris Pinkse <pinkse@gmail.com> and contributors",
    sitename="ReplExit.jl",
    format=Documenter.HTML(;
        canonical="https://NittanyLion.github.io/ReplExit.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Installation" => "installation.md",
        "Usage" => "usage.md",
        "How it works" => "internals.md",
        "Troubleshooting" => "troubleshooting.md",
        "Reference" => "reference.md",
    ],
    checkdocs=:all,
    warnonly=false,
)

deploydocs(;
    repo="github.com/NittanyLion/ReplExit.jl",
    devbranch="main",
)
