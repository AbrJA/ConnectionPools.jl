using Documenter
using Pools

makedocs(
    modules = [Pools],
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://AbrJA.github.io/Pools.jl",
    ),
    pages = [
        "Introduction" => "index.md",
        "Usage" => "usage.md",
        "Examples" => "examples.md",
        "API" => "api.md",
    ],
    repo = Remotes.GitHub("AbrJA", "Pools.jl"),
    sitename = "Pools.jl",
    authors = "Abraham Jaimes"
)

deploydocs(
    repo = Remotes.GitHub("AbrJA", "Pools.jl"),
    push_preview = true
)
