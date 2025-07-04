# Examples

This page provides more detailed examples of how to use `Pools.jl` to manage different types of resources.

## Example: SQLite Connection Pooling

This example demonstrates how to use `ConnectionPools.jl` to manage a pool of `SQLite.jl` database connections.

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

using ConnectionPools
import ConnectionPools: create, clean!

# Implement the required functions
create(::Type{SQLite.DB}) = SQLite.DB("database.db")
clean!(db::SQLite.DB) = DBInterface.close!(db)

# Create a pool of connections with a maximum of 5 connections
pool = ConnectionPool{SQLite.DB}(3)

# Use a connection from the pool
@time Threads.@threads for i in 1:20
    withconnection(pool) do db
        df = DBInterface.execute(db, "SELECT * FROM users LIMIT $i") |> DataFrame
        @info "Thread $(Threads.threadid()) - Number of rows: $(nrow(df))"
    end
end

# Drain the pool (release and finalize all resources)
drain!(pool)
```

## Example: Redis Connection Pooling

This example demonstrates how to use `ConnectionPools.jl` to manage a pool of `Redis.jl` database connections.

```julia
using ConnectionPools, Dates, Redis
import ConnectionPools: create, clean!, check, change! # Functions to be extended

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
pool = ConnectionPool{Connection}(5)

# Use a connection from the pool (using withconnection is recommended)
withconnection(pool) do conn
    # ... use the connection ...
    get(conn.client, "key")
end # The connection is automatically released back to the pool here

# Or, acquire and release manually (less recommended):
conn = acquire!(pool)
# ... use the connection ...
get(conn.client, "key")
release!(pool, conn)

# Drain the pool (release and finalize all resources)
drain!(pool)
```
