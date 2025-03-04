using Documenter
using ConnectionPools

makedocs(
    modules = [ConnectionPools],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://AbrJA.github.io/ConnectionPools.jl",
    ),
    pages = [
        "Introduction" => "index.md",
        "Usage" => "usage.md",
        "Examples" => "examples.md",
        "API" => "api.md",
    ],
    repo = Remotes.GitHub("AbrJA", "ConnectionPools.jl"),
    sitename = "ConnectionPools.jl",
    authors = "Abraham Jaimes"
)

deploydocs(
    repo = Remotes.GitHub("AbrJA", "ConnectionPools.jl"),
    push_preview = true
)
