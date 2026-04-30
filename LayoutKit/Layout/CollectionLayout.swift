import Foundation

public protocol CollectionLayout: AnyObject, Sendable {
    var dataSource: CollectionLayoutDataSource { get }
    
    func invalidateLayout()
    func layoutAttributes(for index: Int, in context: LayoutContext) -> LayoutAttributes?
    func layoutAttributes(in context: LayoutContext) -> [LayoutAttributes]
    func contentSize(in context: LayoutContext) -> CGSize
}
