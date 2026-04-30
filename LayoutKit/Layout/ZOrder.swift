import Foundation

public enum ZOrder: Sendable, Hashable {
    case ascending  // First item on bottom, last on top
    case descending // First item on top, last on bottom
}