# Usage

This page provides detailed instructions on how to use the `Pools.jl` package, including explanations of key concepts, API documentation for all exported functions and types, and examples of common usage patterns.

## Core Concepts

### Resource Pools

A resource pool is a collection of resources that are managed and reused to improve performance.  Instead of creating new resources every time they are needed, a pool maintains a set of available resources and distributes them as requested.  When a resource is no longer needed, it is returned to the pool for later reuse, avoiding the overhead of creating and destroying resources repeatedly.

### Resource Lifecycle

Resources managed by `Pools.jl` go through a specific lifecycle:

1.  **Creation:** New resources are created using the `create(::Type{T})` function.
2.  **Acquisition:** Resources are acquired from the pool using the `acquire!(pool::Pool{T})` function.
3.  **Validation:** Before a resource is given to a user, it is validated using the `validate(resource::T)` function to ensure it is still valid.
4.  **Usage:** The resource is used by the application.
5.  **Update:** Before a resource is returned to the pool, its state can be updated using the `update(resource::T)` function.
6.  **Release:** Resources are returned to the pool using the `release!(pool::Pool{T}, resource::T)` function.
7.  **Finalization:** Resources are finalized (cleaned up) using the `finalize(resource::T)` function when they are no longer needed by the pool (e.g., during pool draining or when they fail validation).

## Using the Pool

### Creating a Pool

To create a resource pool, you need to define your resource type `T` and implement the `create`, `validate`, `update`, and `finalize` functions for that type.  Then, you can create a pool using the `Pool{T}(limit::Int)` constructor.

```julia
using Pools

struct Resource # Define your resource type
    # ... resource data
end

# Implement the required functions
create(::Type{Resource}) = Resource()
update(resource::Resource) = println("Resource updated") # How to update
validate(resource::Resource) = println("Resource validated") # How to validate
finalize(resource::Resource) = println("Resource finalized") # How to finalize

pool = Pool{Resource}(5) # Create a pool with a maximum of 5 resources
```

### Acquiring a Resource

To acquire a resource from the pool, use the acquire!(pool::Pool{T}) function.  This function will either return a free resource from the pool, create a new resource (if below the limit), or block until a resource becomes available.

```julia
resource = acquire!(pool)
# ... use the resource ...
```

### Releasing a Resource

To release a resource back to the pool, use the release!(pool::Pool{T}, resource::T) function.

```julia
release!(pool, resource)
```

### Using withresource (Recommended)

The recommended way to work with pooled resources is to use the withresource(f::Function, pool::Pool{T}) function.  This function automatically acquires a resource, passes it to your function f, and ensures that the resource is released back to the pool, even if errors occur.

```julia
withresource(pool) do resource
    # ... use the resource ...
end # Resource is automatically released here
```

### Draining the Pool

To release and finalize all resources in the pool, use the drain!(pool::Pool{T}) function.  This is typically done when you want to shut down the pool.

```julia
drain!(pool)
```

API
@autodoc(Pools)
