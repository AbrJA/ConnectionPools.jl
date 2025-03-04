# Pools

[![Build Status](https://github.com/AbrJA/Pools.jl/workflows/CI/badge.svg)](https://github.com/AbrJA/Pools.jl/actions)

## Install

```
import Pkg; Pkg.add("Pools")
```

## Purpose 

This package is built to manage `Pool` of objects of any `Type` _(Numbers, Structs, Connections, etc)_

It relies on the custom implementation of the following functions:

```
create(::Type{T}) # How to create the resource
check(::T) # How to check it
change!(::T) # How to update it
clean!(::T) # How to finalize it
```

At least `create` function is required.

## Features

- **Generic:**  Works with any resource type `T`.  You define how to manage resources, and `Pools.jl` handles the rest.
- **Thread-safe:** All operations are thread-safe, allowing concurrent access to the pool from multiple tasks.
- **Memory-safe:** Handles resource allocation, and deallocation, limiting the number of resources in use concurrently.
- **Convenient:** `withresource` Function simplifies the process of acquiring and using resources.

## Examples 

### Generic

Create a `Pool` of `Int`s

```
using Pools
import create

create(::Type{Int}) = rand(1:10)

pool = Pool{Int}(5)

withresource(pool) do value
    println(value)
end 
```

### Redis

To create a `Pool` of `Redis` connections:

- Load the libraries:
```
using Dates, Pools, Redis
```

- Import the functions from `Pool` to be extended (just those needed):
```
import Pools: create, check, change!, clean!
```

- Build the connections struct:
```
mutable struct Connection
    client::RedisConnection
    timestamp::DateTime
end
```

- Implement the required functions for `Type` `Connection`:
```
create(::Type{Connection}) = Connection(RedisConnection(host = "localhost", port = 6379, db = 3), now())
check(conn::Connection) = if now() > conn.timestamp + Minute(1) ping(conn.client) end
change!(conn::Connection) = conn.timestamp = now()
clean!(conn::Connection) = disconnect(conn.client)
```

- Create a `Pool` of `Connection`s with a limit of 5:
```
pool = Pool{Connection}(5)
```

- Use a connection from the pool (using withresource is recommended):
```
withresource(pool) do conn
    # ... use the connection ...
    get(conn.client, "key")
end # The connection is automatically released back to the pool here
```

- Acquire and release manually (less recommended):
```
conn = acquire!(pool)
# ... use instance to extract the resource because it is wrapped into Resource struct ...
try
    get(instance(conn).client, "key")
finally
    release!(pool, conn)
end
```

- Drain the pool (release and finalize all resources):
```
drain!(pool)
```
