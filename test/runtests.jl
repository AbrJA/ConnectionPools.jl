using Test, Pools
import Pools: create, finalize!, update!, validate

@testset "Pools.jl" begin
    create(::Type{Int}) = rand(1:10)

    n = 5
    pool = Pool{Int}(n)

    @test limit(pool) == n
    @test free(pool) == 0
    @test taken(pool) == 0

    value = acquire!(pool)
    @test value isa Int
    @test free(pool) == 0
    @test taken(pool) == 1

    release!(pool, value)
    @test free(pool) == 1
    @test taken(pool) == 0
    @test_throws ArgumentError release!(pool, value)

    drain!(pool)
    @test free(pool) == 0
    @test taken(pool) == 0

end
