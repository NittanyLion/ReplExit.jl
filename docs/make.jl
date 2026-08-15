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
    ],
)

deploydocs(;
    repo="github.com/NittanyLion/ReplExit.jl",
    devbranch="main",
)
