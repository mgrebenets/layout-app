import Foundation
import CoreGraphics

public struct LayoutContext: Hashable, Sendable {
    var bounds: CGRect
    var contentInsets: Insets
    
    var availableWidth: CGFloat {
        bounds.width - contentInsets.horizontal
    }
    
    var availableHeight: CGFloat {
        bounds.height - contentInsets.vertical
    }
    
    public var contentRect: CGRect {
        CGRect(
            x: bounds.minX + contentInsets.left,
            y: bounds.minY + contentInsets.top,
            width: availableWidth,
            height: availableHeight
        )
    }
    
    public init(bounds: CGRect, contentInsets: Insets) {
        self.bounds = bounds
        self.contentInsets = contentInsets
    }
}
