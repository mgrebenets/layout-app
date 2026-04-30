import Foundation

public protocol CollectionLayoutDataSource: Sendable {
    var numberOfItems: Int { get }
}
