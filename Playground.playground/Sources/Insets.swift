import Foundation
import CoreGraphics

public struct Insets: Hashable, Sendable {
    let top: CGFloat
    let left: CGFloat
    let bottom: CGFloat
    let right: CGFloat
    
    static let zero = Insets(top: 0, left: 0, bottom: 0, right: 0)
    
    public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }
    
    public init(uniform: CGFloat) {
        self.init(top: uniform, left: uniform, bottom: uniform, right: uniform)
    }
    
    public init(horizontal: CGFloat, vertical: CGFloat) {
        self.init(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }
    
    var horizontal: CGFloat { left + right }
    var vertical: CGFloat { top + bottom }
}
