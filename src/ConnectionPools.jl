module ConnectionPools

    import Base: show
    export GenericPool, ConnectionPool,
           free, taken, limit,
           acquire!, release!, drain!, withconnection, withresource,
           create, clean!, change!, check

    abstract type Pool{T} end

    """
    create(::Type{T}) where T -> T

    Create a new instance of type `T`.

    This function is called automatically by the pool when a new resource is needed (e.g., when a resource is acquired and the pool is empty or below its limit).  You *must* implement this method for any type `T` that you want to store in a `Pool`.

    # Arguments

    *   `::Type{T}`: The type of the resource to create.  This is a type parameter, not an instance of the type.

    # Returns

    A new resource of type `T`.

    # Throws

    *   `MethodError`: If this function is not implemented for the given type `T`.

    # Example

    ```julia

    using Pools, Redis, Dates
    import Pools: create

    struct Connection
        client::RedisConnection
        timestamp::DateTime
    end

    create(::Type{Connection}) = Connection(RedisConnection(host = "localhost", port = 6379, db = 3), now())
    ```
    """
    create(::Type{T}) where T = error("create not implemented for $(T)")

    """
    clean!(resource::T) where T

    Clean up resources associated with a resource of type `T`.

    This function is called automatically by the pool in the following situations:

    *   When a resource fails validation (as determined by the `check` function).
    *   When a resource is removed from the pool (e.g., during pool draining or when the pool's limit is reduced).

    You *should* implement this method to release any external resources held by the resource (e.g., closing connections, freeing memory, etc.).  If you do not implement this method, the default implementation will do nothing.

    # Arguments

    *   `resource::T`: The resource to clean up.

    # Generic Method

    A generic `clean!(::T) where T` method is provided, which does nothing. It is *strongly recommended* that you implement a specific `clean!` method if your resource requires any cleanup.

    # Example

    ```julia
    using Pools, Redis, Dates
    import Pools: create, clean!

    struct Connection
        client::RedisConnection
        timestamp::DateTime
    end

    function clean!(redis::Connection)
        Redis.disconnect(redis.client)
    end
    ```
    """
    function clean!(::T) where T end

    """
    change!(resource::T) where T

    Change the state of a resource of type `T` during releasing before it is reused.

    This function is called automatically by the pool when a resource is returned to the pool via `release!`.  It provides an opportunity to update the resource's internal state, such as resetting connection parameters, change timestamps, etc.

    You *should* implement this method if your resource requires any state changes before it can be reused.  If no update is needed, you can leave this method unimplemented, and the default implementation will do nothing.

    # Arguments

    *   `resource::T`: The resource to modify.

    # Generic Method

    A generic `change!(::T) where T` method is provided, which does nothing. This serves as a default implementation so that if you do not define a specific `change!` method for your resource type. However, it is *strongly recommended* that you implement a specific `change!` method if your resource requires any state changes.

    # Example

    ```julia
    using Pools, Redis, Dates
    import Pools: create, change!

    mutable struct Connection
        client::RedisConnection
        timestamp::DateTime
    end

    function change!(redis::Connection)
        redis.timestamp = now()
    end
    ```
    """
    function change!(::T) where T end

    """
    check(resource::T) where T

    Check the validity of a resource of type `T`.

    This function is called automatically by the pool during resource acquisition (`acquire!`).  If `check` fails, the resource is considered invalid, and the pool will attempt to create a new resource (or retrieve another free resource).  It is essential to implement this method to ensure that the pool only provides valid resources to users.

    # Arguments

    *   `resource::T`: The resource to validate.

    # Generic Method

    A generic `check(::T) where T` method is provided, which does nothing.  This means that if you do not define a specific `check` method for your resource type, all resources will be considered valid.  While this might seem convenient, it is *strongly recommended* that you implement a specific `check` method that performs appropriate checks for your resource type.  Relying on the generic method without proper validation can lead to unexpected errors and resource leaks.

    # Example

    ```julia
    using Pools, Redis, Dates
    import Pools: create, check

    struct Connection
        client::RedisConnection
        timestamp::DateTime
    end

    function check(redis::Connection)
        ping(redis.client)
    end
    ```
    """
    function check(::T) where T end

    """
    GenericPool{T}(limit::Int)

    A thread-safe resource pool manager for resources of type `T`.

    This struct implements a resource pool, managing the acquisition and release of resources with a maximum concurrency limit.  It's designed to be used with various resource types, such as database connections or other objects that need to be managed and reused efficiently.

    # Type Parameters

    *   `T`: The type of resource managed by the pool.

    # Fields

    *   `limit::Int`: The maximum number of resources that can be in use concurrently.
    *   `free::Vector{T}`: A vector containing the currently available (free) resources in the pool.
    *   `taken::Set{T}`: A set containing the resources that are currently in use (taken) by users.
    *   `lock::ReentrantLock`: A reentrant lock used for thread safety.  All operations on the pool are protected by this lock.
    *   `condition::Threads.Condition`: A condition variable used to notify waiting tasks when a resource becomes available.

    # Constructor

    ```julia
    GenericPool{T}(limit::Int) where T
    Creates a new resource pool for resources of type T with a maximum concurrency limit of limit.

    # Arguments
    limit::Int: The maximum number of resources allowed in the pool. Must be a positive integer.

    # Throws
    ArgumentError: If limit is not a positive integer.

    # Example

    ```julia
    using Pools, Redis, Dates

    struct Connection
        client::RedisConnection
        timestamp::DateTime
    end

    pool = GenericPool{Connection}(3)
    ```
    """
    struct GenericPool{T} <: Pool{T}
        limit::Int
        free::Vector{T}
        taken::Set{T}
        lock::ReentrantLock
        condition::Threads.Condition

        function GenericPool{T}(limit::Int) where T
            limit > 0 || throw(ArgumentError("limit must be positive"))
            lock = ReentrantLock()
            condition = Threads.Condition(lock)
            new{T}(limit, Vector{T}(), Set{T}(), lock, condition)
        end
    end

    """
    ConnectionPool{T}(limit::Int) where T -> GenericPool{T}

    Alias for `GenericPool{T}`.

    This function is an alias for `GenericPool{T}` and is provided for convenience.  It creates a new resource pool for resources of type `T` with a maximum concurrency limit of `limit`.

    # Arguments

    *   `limit::Int`: The maximum number of resources allowed in the pool. Must be a positive integer.

    # Throws

    *   `ArgumentError`: If `limit` is not a positive integer.
    """
    ConnectionPool = GenericPool

    Base.show(io::IO, pool::Pool{T}) where T = begin
        lock(pool.lock)  do
           print(io, "Pool{$T} of size $(pool.limit) with $(length(pool.free)) free and $(length(pool.taken)) taken resources")
        end
    end

    """
    free(pool::Pool{T}) where T -> Int

    Return the number of free resources currently available in the pool.

    This function provides a thread-safe way to check how many resources are currently available for immediate acquisition in the pool. It does *not* include resources that are currently in use (taken).

    # Arguments

    *   `pool::Pool{T}`: The resource pool to query.

    # Returns

    The number of free resources in the pool.

    # Thread Safety

    This operation is thread-safe.

    # Example

    ```julia
    using Pools

    create(::Type{Int}) = rand(1:10)

    pool = GenericPool{Int}(3)
    free(pool)
    ```
    """
    function free(pool::Pool{T}) where T
        lock(pool.lock) do
            return length(pool.free)
        end
    end

    """
    taken(pool::Pool{T}) where T -> Int

    Return the number of resources currently taken (in use) from the pool.

    This function provides a thread-safe way to check how many resources are currently in use (taken) from the pool.  It does *not* include resources that are free and available for immediate acquisition.

    # Arguments

    *   `pool::Pool{T}`: The resource pool to query.

    # Returns

    The number of taken resources in the pool.

    # Thread Safety

    This operation is thread-safe.

    # Example

    ```julia
    using Pools

    create(::Type{Int}) = rand(1:10)

    pool = GenericPool{Int}(3)
    taken(pool)
    ```
    """
    function taken(pool::Pool{T}) where T
        lock(pool.lock) do
            return length(pool.taken)
        end
    end

    """
    limit(pool::Pool{T}) where T -> Int

    Return the maximum number of resources that the pool can hold concurrently.

    This function returns the `limit` of the pool, which represents the maximum number of resources that can be in use (taken) at any given time.

    # Arguments

    *   `pool::Pool{T}`: The resource pool to query.

    # Returns

    The maximum number of concurrent resources allowed by the pool.

    # Thread Safety

    This operation is thread-safe.  Access to the `pool.limit` field is inherently atomic in Julia.

    # Example

    ```julia
    using Pools

    create(::Type{Int}) = rand(1:10)

    pool = GenericPool{Int}(5)
    limit(pool)
    ```
    """
    function limit(pool::Pool{T}) where T
        return pool.limit
    end

    """
    acquire!(pool::Pool{T}) where T -> T

    Acquire a resource from the pool.

    This function attempts to retrieve a resource from the pool.  It will reuse valid cached resources if available, create new resources if the pool is below its limit, or block until a resource becomes available if the pool is at its limit and no valid cached resources are available.

    # Arguments

    *   `pool::Pool{T}`: The resource pool to acquire from.

    # Returns

    A resource of type `T`.

    # Throws

    *   `MethodError`: If the `create(::Type{T})` function is not implemented for the resource type `T`.  This function is essential for the `Pool` to create new resources when needed.  See the documentation for `create` for more details.
    *   Exceptions thrown by the `check(resource::T)` function. If `check` throws an exception, the resource is considered invalid and discarded.

    # Thread Safety

    This operation is thread-safe.

    # Example

    ```julia
    using Redis, Dates

    struct Connection
        client::RedisConnection
        timestamp::DateTime
    end

    create(::Type{Connection}) = Connection(RedisConnection(host = "localhost", port = 6379, db = 3), now())
    check(redis::Connection) = ping(redis.client)

    pool = ConnectionPool{Connection}(3)
    conn = acquire!(pool)
    ```
    """
    function acquire!(pool::Pool{T}) where T
        lock(pool.lock) do
            while true
                while !isempty(pool.free)
                    resource = pop!(pool.free)
                    try
                        check(resource)
                    catch
                        clean!(resource)
                        continue
                    end
                    push!(pool.taken, resource)
                    return resource
                end
                if length(pool.taken) < pool.limit
                    resource = create(T)
                    push!(pool.taken, resource)
                    return resource
                end
                wait(pool.condition)
            end
        end
    end

    """
    release!(pool::Pool{T}, resource::T)

    Release a resource back to the pool.

    This function returns a resource to the pool, making it available for reuse.  It changes the resource's state (using the `change!` function) and notifies any waiting tasks that a resource has become available.

    # Arguments

    *   `pool::Pool{T}`: The resource pool to release the resource to.
    *   `resource::T`: The resource to release.

    # Throws

    *   `ArgumentError`: If the provided `resource` does not belong to the pool (i.e., it was not acquired from this pool).
    *   Exceptions thrown by the `change!(resource::T)` function.

    # Thread Safety

    This operation is thread-safe.

    # Example

    ```julia
    using Redis, Dates

    struct Connection
        client::RedisConnection
        timestamp::DateTime
    end

    create(::Type{Connection}) = Connection(RedisConnection(host = "localhost", port = 6379, db = 3), now())
    change!(redis::Connection) = redis.timestamp = now()

    pool = ConnectionPool{Connection}(3)
    conn = acquire!(pool)
    release!(pool, conn)
    ```
    """
    function release!(pool::Pool{T}, resource::T) where T
        lock(pool.lock) do
            if resource in pool.taken
                delete!(pool.taken, resource)
                change!(resource)
                push!(pool.free, resource)
                notify(pool.condition, all = false)
            else
                throw(ArgumentError("Resource does not belong to the pool"))
            end
        end
    end

    function withresource(f, pool::Pool{T}) where T
        @warn "withresource is deprecated, use withconnection instead"
    end

    """
    withconnection(f::Function, pool::Pool{T}) where T

    Execute a function with a resource from the pool, automatically handling acquisition and release.

    This function provides a safe and convenient way to use resources from the pool.  It acquires a resource, passes it to the provided function `f`, and *guarantees* that the resource is released back to the pool, even if an error occurs within the function.  This is the *recommended* way to work with pooled resources, as it prevents resource leaks and simplifies resource management.

    # Arguments

    *   `f::Function`: A function that accepts a resource of type `T` as its argument. This function performs the operations you want to do with the resource.
    *   `pool::Pool{T}`: The resource pool to acquire the resource from.

    # Returns

    The value returned by the function `f`.

    # Throws

    *   Exceptions thrown by the function `f`.  These exceptions will be propagated after the resource is released.
    *   `MethodError`: If the `create(::Type{T})` or `check(resource::T)` functions are not implemented for the resource type `T`.

    # Example

    ```julia

    using Redis, Dates

    struct Connection
        client::RedisConnection
        timestamp::DateTime
    end

    create(::Type{Connection}) = Connection(RedisConnection(host = "localhost", port = 6379, db = 3), now())

    pool = ConnectionPool{Connection}(3)

    withconnection(pool) do redis
        ping(redis.client)
    end
    ```
    """
    function withconnection(f, pool::Pool{T}) where T
        resource = acquire!(pool)
        try
            return f(resource)
        finally
            release!(pool, resource)
        end
    end

    """
    drain!(pool::Pool{T}) where T

    Drain the resource pool, releasing and finalizing all resources.

    This function releases all resources currently held by the pool, both free and taken. It waits for all taken resources to be released back to the pool before finalizing them. This is typically used when you want to shut down the pool or when you need to ensure that all resources are properly cleaned up.

    # Arguments

    *   `pool::Pool{T}`: The resource pool to drain.

    # Thread Safety

    This operation is thread-safe.

    # Example

    ```julia
    using Redis, Dates

    struct Connection
        client::RedisConnection
        timestamp::DateTime
    end

    create(::Type{Connection}) = Connection(RedisConnection(host = "localhost", port = 6379, db = 3), now())
    clean!(redis::Connection) = Redis.disconnect(redis.client)

    pool = ConnectionPool{Connection}(3)

    withconnection(pool) do redis
        ping(redis.client)
    end

    drain!(pool)
    ```
    """
    function drain!(pool::Pool{T}) where T
        lock(pool.lock) do
            while length(pool.taken) > 0
                wait(pool.condition)
            end
            while !isempty(pool.free)
                clean!(pop!(pool.free))
            end
        end
    end

end
