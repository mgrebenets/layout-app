import Foundation
import CoreGraphics
import Synchronization

public final class CachedLayout<Strategy: LayoutStrategy>: CollectionLayout {
    public let dataSource: CollectionLayoutDataSource
    private let strategy: Strategy

    private struct CacheState: Sendable {
        var attributes: [Int: LayoutAttributes] = [:]
        var context: LayoutContext?
        var contentSize: CGSize?
        var cachedItemCount: Int?
    }

    private let cache = Mutex(CacheState())

    init(strategy: Strategy, dataSource: CollectionLayoutDataSource) {
        self.strategy = strategy
        self.dataSource = dataSource
    }

    public func invalidateLayout() {
        cache.withLock { state in
            state.attributes.removeAll()
            state.context = nil
            state.contentSize = nil
            state.cachedItemCount = nil
        }
    }

    public func layoutAttributes(for index: Int, in context: LayoutContext) -> LayoutAttributes? {
        guard index >= 0 && index < dataSource.numberOfItems else { return nil }

        let itemCount = dataSource.numberOfItems
        return cache.withLock { state in
            // Invalidate cache if context or itemCount changed
            if state.context != context || state.cachedItemCount != itemCount {
                state.attributes.removeAll()
                state.context = context
                state.contentSize = nil
                state.cachedItemCount = itemCount
            }

            if let cached = state.attributes[index] {
                return cached
            }

            let attributes = strategy.computeAttributes(
                for: index,
                in: context,
                itemCount: itemCount
            )
            state.attributes[index] = attributes
            return attributes
        }
    }

    public func layoutAttributes(in context: LayoutContext) -> [LayoutAttributes] {
        let itemCount = dataSource.numberOfItems

        return cache.withLock { state in
            // Invalidate cache if context or itemCount changed
            if state.context != context || state.cachedItemCount != itemCount {
                state.attributes.removeAll()
                state.context = context
                state.contentSize = nil
                state.cachedItemCount = itemCount
            }

            if state.attributes.count == itemCount {
                return (0..<itemCount).compactMap { state.attributes[$0] }
            }

            let all = strategy.computeAllAttributes(in: context, itemCount: itemCount)
            for attr in all {
                state.attributes[attr.index] = attr
            }
            state.cachedItemCount = itemCount

            return all
        }
    }

    public func contentSize(in context: LayoutContext) -> CGSize {
        let itemCount = dataSource.numberOfItems
        return cache.withLock { state in
            // Invalidate cache if context or itemCount changed
            if state.context != context || state.cachedItemCount != itemCount {
                state.attributes.removeAll()
                state.context = context
                state.contentSize = nil
                state.cachedItemCount = itemCount
            }

            if let cached = state.contentSize {
                return cached
            }

            let size = strategy.computeContentSize(in: context, itemCount: itemCount)
            state.contentSize = size
            return size
        }
    }
}
