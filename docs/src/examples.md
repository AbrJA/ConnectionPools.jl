# Examples

This page provides more detailed examples of how to use `Pools.jl` to manage different types of resources.

## Example 1: Redis Connection Pooling

This example demonstrates how to use `Pools.jl` to manage a pool of database connections using the `Redis.jl` package.

```julia
using Dates, Pools, Redis
import Pools: create, clean! # Functions to be extended

mutable struct Connection
    client::RedisConnection
    timestamp::DateTime
end

# Implement the required functions
create(::Type{Connection}) = Connection(RedisConnection(host = "localhost", port = 6379, db = 3), now())
check(conn::Connection) = ping(conn.client)
change!(conn::Connection) = conn.timestamp = now()
clean!(conn::Connection) = disconnect(conn.client)

# Create a pool of connections with a maximum of 5 connections
pool = Pool{Connection}(5)

# Use a connection from the pool (using withresource is recommended)
withresource(pool) do conn
    # ... use the connection ...
    get(conn.client, "key")
end # The connection is automatically released back to the pool here

# Or, acquire and release manually (less recommended):
conn = acquire!(pool)
# ... use instance to extract the resource because it is wrapped ...
get(instance(conn).client, "key")
release!(pool, conn)

# Drain the pool (release and finalize all resources)
drain!(pool)
```
