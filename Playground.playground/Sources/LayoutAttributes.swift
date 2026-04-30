import Foundation
import CoreGraphics

public struct LayoutAttributes: Hashable, Sendable {
    public var index: Int
    public var frame: CGRect
    public var zIndex: Int = 0
    
    public init(index: Int, frame: CGRect, zIndex: Int = 0) {
        self.index = index
        self.frame = frame
        self.zIndex = zIndex
    }
    
    public var center: CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
    
    public var size: CGSize {
        frame.size
    }
}
