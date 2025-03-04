# Pools

[![Build Status](https://github.com/AbrJA/Pools.jl/workflows/CI/badge.svg)](https://github.com/AbrJA/Pools.jl/actions)

## Install

```
import Pkg; Pkg.add("Pools")
```

## Example

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
