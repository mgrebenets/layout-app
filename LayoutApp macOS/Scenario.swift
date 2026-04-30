import Foundation

/// Defines the available test scenarios for the layout system
public struct Scenario: Identifiable, Hashable {
    public let id = UUID()
    public let title: String
    public let description: String
    public let type: ScenarioType

    public init(title: String, description: String, type: ScenarioType) {
        self.title = title
        self.description = description
        self.type = type
    }
}

public enum ScenarioType: CaseIterable {
    case overview          // The current "everything-at-once" layout
    case nestedGrids       // Focus on nested SKCollectionNodes
    case nodePooling       // Performance test with NodePool
    case circularAndStack  // Focus on Circular and Stack layouts
    case dragAndDrop       // Interaction test with NodeCoordinator
}
