import Foundation

/// A pool for reusing nodes to improve performance and reduce memory allocations.
/// Nodes are stored by their reuse identifier and can be dequeued for reuse.
/// Thread-safe through actor isolation.
public actor NodePool {

    // MARK: - Private Properties

    /// Dictionary storing pools of nodes by their reuse identifier
    private var pools: [String: [ReusableNode]] = [:]

    /// Maximum number of nodes to keep in each pool
    private let maxPoolSize: Int

    // MARK: - Statistics

    /// Total number of nodes created (not reused)
    private(set) var totalCreated: Int = 0

    /// Total number of nodes reused from the pool
    private(set) var totalReused: Int = 0

    // MARK: - Initialization

    /// Create a new node pool
    /// - Parameter maxPoolSize: Maximum number of nodes to keep per reuse identifier (default: 20)
    public init(maxPoolSize: Int = 20) {
        self.maxPoolSize = maxPoolSize
    }

    // MARK: - Public Methods

    /// Dequeue a reusable node from the pool, or create a new one if none available
    /// - Parameters:
    ///   - identifier: The reuse identifier for the type of node
    ///   - create: Closure that creates a new node if one is not available in the pool
    /// - Returns: A reusable node, either from the pool or newly created
    public func dequeueReusableNode<T: ReusableNode>(
        withIdentifier identifier: String,
        create: () -> T
    ) -> T {
        // Try to get a node from the pool
        if var pool = pools[identifier], !pool.isEmpty {
            let node = pool.removeLast() as! T
            pools[identifier] = pool

            // Prepare the node for reuse
            node.prepareForReuse()

            totalReused += 1
            return node
        }

        // No node available, create a new one
        let node = create()
        totalCreated += 1
        return node
    }

    /// Return a node to the pool for later reuse
    /// - Parameter node: The node to return to the pool
    public func enqueueForReuse(_ node: ReusableNode) {
        let identifier = node.reuseIdentifier
        var pool = pools[identifier] ?? []

        // Only add to pool if we haven't reached the maximum size
        guard pool.count < maxPoolSize else {
            // Pool is full, node will be deallocated
            return
        }

        pool.append(node)
        pools[identifier] = pool
    }

    /// Return multiple nodes to the pool
    /// - Parameter nodes: The nodes to return to the pool
    public func enqueueForReuse(_ nodes: [ReusableNode]) {
        for node in nodes {
            enqueueForReuse(node)
        }
    }

    /// Clear all nodes from the pool
    public func clear() {
        pools.removeAll()
    }

    /// Clear nodes for a specific reuse identifier
    /// - Parameter identifier: The reuse identifier to clear
    public func clear(identifier: String) {
        pools.removeValue(forKey: identifier)
    }

    /// Get the current size of the pool for a specific identifier
    /// - Parameter identifier: The reuse identifier
    /// - Returns: Number of nodes currently in the pool for this identifier
    public func poolSize(for identifier: String) -> Int {
        return pools[identifier]?.count ?? 0
    }

    /// Get the total number of nodes currently in all pools
    public var totalPooledNodes: Int {
        return pools.values.reduce(0) { $0 + $1.count }
    }

    /// Get statistics about pool usage
    public var statistics: PoolStatistics {
        return PoolStatistics(
            totalCreated: totalCreated,
            totalReused: totalReused,
            currentPoolSize: totalPooledNodes,
            reuseRate: totalReused + totalCreated > 0
                ? Double(totalReused) / Double(totalReused + totalCreated)
                : 0
        )
    }

    /// Reset statistics
    public func resetStatistics() {
        totalCreated = 0
        totalReused = 0
    }
}

// MARK: - Statistics

/// Statistics about node pool usage
public struct PoolStatistics {
    /// Total number of nodes created (not from pool)
    public let totalCreated: Int

    /// Total number of nodes reused from pool
    public let totalReused: Int

    /// Current number of nodes in the pool
    public let currentPoolSize: Int

    /// Percentage of nodes that were reused (0.0 to 1.0)
    public let reuseRate: Double

    /// Total number of node requests (created + reused)
    public var totalRequests: Int {
        totalCreated + totalReused
    }
}
