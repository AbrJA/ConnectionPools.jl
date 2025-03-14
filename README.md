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

### SQLite

To create a `ConnectionPool` of `SQLite` connections:

```julia
using DBInterface, DataFrames, SQLite

# Connect to SQLite database
db = SQLite.DB("database.db")

# Create table if it doesn't exist
DBInterface.execute(db, "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)")

# Begin a transaction to speed up batch inserts
DBInterface.execute(db, "BEGIN TRANSACTION")

# Insert 1000 records into the users table
for i in 1:1000
    name = "User$i"
    age = rand(20:60)  # Random age between 20 and 60
    DBInterface.execute(db, "INSERT INTO users (name, age) VALUES (?, ?)", (name, age,))
end

# Commit transaction
DBInterface.execute(db, "COMMIT")

# Close database connection
DBInterface.close!(db)
```

- Load the libraries
```julia
using ConnectionPools, DBInterface, DataFrames, SQLite
```

- Import the functions from `ConnectionPools` to be extended (just those needed):
```julia
import ConnectionPools: create, clean!
```

- Implement the required functions:
```julia
create(::Type{SQLite.DB}) = SQLite.DB("database.db")
clean!(db::SQLite.DB) = DBInterface.close!(db)
```

- Create a `ConnectionPool` of `SQLite.DB` with a limit of 5:
```julia
pool = ConnectionPool{SQLite.DB}(5)
```

- Use the connections from the pool (using withresource is recommended):
```julia
@time Threads.@threads for i in 1:20
    withresource(pool) do db
        df = DBInterface.execute(db, "SELECT * FROM users LIMIT $i") |> DataFrame
        @info "Thread $(Threads.threadid()) - Number of rows: $(nrow(df))"
    end
end
```

- Drain the pool (release and finalize all resources):
```julia
drain!(pool)
```

### Redis

To create a `ConnectionPool` of `Redis` connections:

- Load the libraries:
```julia
using ConnectionPools, Dates, Redis
```

- Import the functions from `ConnectionPools` to be extended:
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

- Use a connection from the pool:
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

- Drain the pool:
```julia
drain!(pool)
```
