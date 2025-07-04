using ConnectionPools, DBInterface, DataFrames, SQLite, Test
import ConnectionPools: create, clean!, change!, check

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

create(::Type{SQLite.DB}) = SQLite.DB("database.db")
clean!(db::SQLite.DB) = DBInterface.close!(db)

@testset "ConnectionPools.jl" begin
    n = max(2, Threads.nthreads())
    pool = ConnectionPool{SQLite.DB}(n)

    @test limit(pool) == n
    @test free(pool) == 0
    @test taken(pool) == 0

    db1 = acquire!(pool)
    db2 = acquire!(pool)
    @test db1 isa SQLite.DB
    @test db2 isa SQLite.DB
    @test free(pool) == 0
    @test taken(pool) == 2

    release!(pool, db1)
    @test free(pool) == 1
    @test taken(pool) == 1
    release!(pool, db2)
    @test free(pool) == 2
    @test taken(pool) == 0
    @test_throws ArgumentError release!(pool, db1)

    Threads.@threads for i in 1:n
        withconnection(pool) do db
            df = DBInterface.execute(db, "SELECT * FROM users LIMIT $i") |> DataFrame
            @info "Thread $(Threads.threadid()) - Number of rows: $(nrow(df))"
            sleep(0.1)
        end
    end
    @test free(pool) == n
    @test taken(pool) == 0

    drain!(pool)
    @test free(pool) == 0
    @test taken(pool) == 0

end
