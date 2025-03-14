# Pools.jl

`ConnectionPools.jl` provides a generic and thread-safe resource pooling mechanism for Julia.  It's designed to efficiently manage and reuse resources of any type `T`, such as database connections, network sockets, or other expensive-to-create objects.  This can significantly improve the performance of applications that require access to multiple resources concurrently.

## Key Features

*   **Generic:**  Works with any resource type `T`.  You define how to create, check, change, and clean resources, and `ConnectionPools.jl` handles the rest.
*   **Thread-safe:**  All operations are thread-safe, allowing concurrent access to the pool from multiple tasks.
*   **Resource Management:**  Handles resource creation, validation, allocation, and deallocation, limiting the number of resources in use concurrently.
*   **Automatic Cleanup:** Provides mechanisms for cleaning up resources when they are no longer needed (e.g., when the pool is drained or when resources fail validation).
*   **Convenient `withresource` Function:** Simplifies the process of acquiring and using resources, ensuring they are automatically released back to the pool, even if errors occur.

## Installation

```julia
] add ConnectionPools
```

## Quick Start

```julia
using ConnectionPools, Redis
import ConnectionPools: create # Functions to be extended

# Implement the required functions
create(::Type{RedisConnection}) = RedisConnection(host = "localhost", port = 6379, db = 3)

# Create a pool of connections with a maximum of 5 connections
pool = ConnectionPool{RedisConnection}(5)

# Use a connection from the pool (using withresource is recommended)
withresource(pool) do conn
    ping(conn)
    # ... use the connection ...
end # The connection is automatically released back to the pool here

# Or, acquire and release manually (less recommended):
conn = acquire!(pool)
# ... use the connection ...
ping(conn)
release!(pool, conn)

# Drain the pool (release and finalize all resources)
drain!(pool)
```

## Usage
For detailed usage instructions and API documentation, please see the Usage page.

## Examples
More comprehensive examples demonstrating various use cases and features can be found on the Examples page.

## API
The full API documentation, including all functions and types, is available on the API page.

## Contributing
Contributions are welcome! Please see the Contributing page for guidelines.

## License
This package is distributed under the MIT License.
