using ConnectionPools, Test
import ConnectionPools: create, clean!, change!, check

counter = Ref(0)
function create(::Type{Int})
    counter[] += 1
    return counter[]
end

@testset "Pools.jl" begin
    n = max(2, Threads.nthreads())
    pool = GenericPool{Int}(n)

    @test limit(pool) == n
    @test free(pool) == 0
    @test taken(pool) == 0

    value1 = acquire!(pool)
    value2 = acquire!(pool)
    @test value1 isa Int
    @test free(pool) == 0
    @test taken(pool) == 2

    release!(pool, value1)
    @test free(pool) == 1
    @test taken(pool) == 1
    release!(pool, value2)
    @test free(pool) == 2
    @test taken(pool) == 0
    @test_throws ArgumentError release!(pool, value1)

    Threads.@threads for _ in 1:n
        withresource(pool) do value
            sleep(0.1)
            value
        end
    end
    @test free(pool) == n
    @test taken(pool) == 0

    drain!(pool)
    @test free(pool) == 0
    @test taken(pool) == 0

end
