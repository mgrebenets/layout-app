import Foundation
import CoreGraphics

public protocol LayoutStrategy: Sendable {
    /// Compute single item (can be optimized for mathematical layouts)
    func computeAttributes(
        for index: Int,
        in context: LayoutContext,
        itemCount: Int
    ) -> LayoutAttributes?
    
    /// Compute all items (default calls single-item version)
    func computeAllAttributes(
        in context: LayoutContext,
        itemCount: Int
    ) -> [LayoutAttributes]
    
    /// Compute content size (default uses max frame)
    func computeContentSize(
        in context: LayoutContext,
        itemCount: Int
    ) -> CGSize
}

extension LayoutStrategy {
    public func computeAllAttributes(
        in context: LayoutContext,
        itemCount: Int
    ) -> [LayoutAttributes] {
        (0..<itemCount).compactMap {
            computeAttributes(for: $0, in: context, itemCount: itemCount)
        }
    }
    
    public func computeContentSize(
        in context: LayoutContext,
        itemCount: Int
    ) -> CGSize {
        let attributes = computeAllAttributes(in: context, itemCount: itemCount)
        guard !attributes.isEmpty else { return .zero }
        
        let maxX = attributes.map(\.frame.maxX).max() ?? 0
        let maxY = attributes.map(\.frame.maxY).max() ?? 0
        
        return CGSize(width: maxX, height: maxY)
    }
}
