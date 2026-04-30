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
        }
    }

    public func layoutAttributes(for index: Int, in context: LayoutContext) -> LayoutAttributes? {
        guard index >= 0 && index < dataSource.numberOfItems else { return nil }

        return cache.withLock { state in
            if state.context != context {
                state.attributes.removeAll()
                state.context = context
                state.contentSize = nil
            }

            if let cached = state.attributes[index] {
                return cached
            }

            let attributes = strategy.computeAttributes(
                for: index,
                in: context,
                itemCount: dataSource.numberOfItems
            )
            state.attributes[index] = attributes
            return attributes
        }
    }

    public func layoutAttributes(in context: LayoutContext) -> [LayoutAttributes] {
        let itemCount = dataSource.numberOfItems

        return cache.withLock { state in
            if state.context != context {
                state.attributes.removeAll()
                state.context = context
                state.contentSize = nil
            }

            if state.attributes.count == itemCount {
                return (0..<itemCount).compactMap { state.attributes[$0] }
            }

            let all = strategy.computeAllAttributes(in: context, itemCount: itemCount)
            for attr in all {
                state.attributes[attr.index] = attr
            }

            return all
        }
    }

    public func contentSize(in context: LayoutContext) -> CGSize {
        cache.withLock { state in
            if state.context != context {
                state.attributes.removeAll()
                state.context = context
                state.contentSize = nil
            }

            if let cached = state.contentSize {
                return cached
            }

            let size = strategy.computeContentSize(in: context, itemCount: dataSource.numberOfItems)
            state.contentSize = size
            return size
        }
    }
}
