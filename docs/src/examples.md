# Examples

This page provides more detailed examples of how to use `Pools.jl` to manage different types of resources.

## Example 1: Redis Connection Pooling

This example demonstrates how to use `Pools.jl` to manage a pool of database connections using the `Redis.jl` package.

```julia
using Pools, Redis
import Pools: create # Functions to be extended

# Implement the required functions
create(::Type{RedisConnection}) = RedisConnection(host = "localhost", port = 6379, db = 3)

# Create a pool of connections with a maximum of 5 connections
pool = Pool{RedisConnection}(5)

# Use a connection from the pool (using withresource is recommended)
withresource(pool) do conn
    ping(conn)
    # ... use the connection ...
end # The connection is automatically released back to the pool here

# Or, acquire and release manually (less recommended):
conn = acquire!(pool)
println("Acquired connection")
# ... use instance to extract the resource ...
ping(instance(conn))
# ... use the connection ...
release!(pool, conn)

# Drain the pool (release and finalize all resources)
drain!(pool)
```
