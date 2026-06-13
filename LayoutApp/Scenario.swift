import Foundation

/// One of the playable card games on the GameEngine.
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
    case war        // Playable War card game on the GameEngine
    case durak      // Playable Durak card game on the GameEngine
    case bura       // Playable Bura card game on the GameEngine
    case solitaire  // Playable Klondike solitaire on the GameEngine
}
