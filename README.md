# ConnectionPools

[![Build Status](https://github.com/AbrJA/Pools.jl/workflows/CI/badge.svg)](https://github.com/AbrJA/ConnectionPools.jl/actions)

## Install

```
import Pkg; Pkg.add("ConnectionPools")
```

## Goal

**Pool** is a collection of reusable resources that can be efficiently managed and allocated to avoid the overhead of creating and destroying them repeatedly. This package is built to manage `Pool` of objects of any `Type` mainly focus on database connections.

It relies on the custom implementation of the following functions:

```julia
create(::Type{T}) # How to create the resource
check(::T) # How to check it
change!(::T) # How to update it
clean!(::T) # How to finalize it
```

At least `create` function is required.

## Features

- **Generic:**  Works with any resource type `T`.  You define how to manage resources, and `ConnectionPools.jl` handles the rest.
- **Thread-safe:** All operations are thread-safe, allowing concurrent access to the pool from multiple tasks.
- **Memory-safe:** Handles resource allocation, and deallocation, limiting the number of resources in use concurrently.
- **Convenient:** Function `withresource` simplifies the process of acquiring and using resources.

## Examples

### Redis

To create a `ConnectionPool` of `Redis` connections:

- Load the libraries:
```julia
using ConnectionPools, Dates, Redis
```

- Import the functions from `ConnectionPools` to be extended (just those needed):
```julia
import ConnectionPools: create, check, change!, clean!
```

- Build the `Resource` struct:
```julia
mutable struct Resource
    conn::RedisConnection
    timestamp::DateTime
end
```

- Implement the required functions for `Type` `Resource`:
```julia
create(::Type{Resource}) = Resource(RedisConnection(host = "localhost", port = 6379, db = 3), now())
check(resource::Resource) = if now() > resource.timestamp + Minute(1) ping(resource.conn) end
change!(resource::Resource) = resource.timestamp = now()
clean!(resource::Resource) = disconnect(resource.conn)
```

- Create a `ConnectionPool` of `Connection`s with a limit of 5:
```julia
pool = ConnectionPool{Resource}(5)
```

- Use a connection from the pool (using withresource is recommended):
```julia
withresource(pool) do resource
    # ... use the connection ...
    get(resource.conn, "key")
end # The connection is automatically released back to the pool here
```

- Acquire and release manually (less recommended):
```julia
resource = acquire!(pool)
try
    get(resource.conn, "key")
finally
    release!(pool, resource)
end
```

- Drain the pool (release and finalize all resources):
```julia
drain!(pool)
```

