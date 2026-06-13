import SwiftUI
import SpriteKit

struct LandingPageView: View {
    let scenarios = [
        Scenario(title: "War", description: "Play the War card game end-to-end on the GameEngine", type: .war),
        Scenario(title: "Durak", description: "Play Durak vs. a simple AI — pick your cards to attack and defend", type: .durak),
        Scenario(title: "Bura", description: "Play Bura vs. a simple AI — trump trick-taking, race to 31 points", type: .bura),
        Scenario(title: "Solitaire", description: "Play Klondike — drag cards between piles, click to send to foundations", type: .solitaire)
    ]

    @State private var fullScreenGame: Scenario?

    var body: some View {
        if let game = fullScreenGame, game.type == .durak {
            // Durak takes over the whole screen (no nav title / safe-area waste); back + gear are overlays.
            DurakHostView(onClose: { fullScreenGame = nil })
        } else {
            NavigationStack {
                List(scenarios) { scenario in
                    if scenario.type == .durak {
                        Button { fullScreenGame = scenario } label: { row(scenario) }
                            .buttonStyle(.plain)
                    } else {
                        NavigationLink(destination: ScenarioDetailView(scenario: scenario)) { row(scenario) }
                    }
                }
                .navigationTitle("Card Games")
            }
        }
    }

    private func row(_ scenario: Scenario) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(scenario.title)
                .font(.headline)
            Text(scenario.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct ScenarioDetailView: View {
    let scenario: Scenario

    private func makeScene() -> SKScene {
        switch scenario.type {
        case .war:       return WarScene(size: CGSize(width: 1024, height: 768))
        case .durak:     return DurakScene(size: CGSize(width: 1024, height: 768))
        case .bura:      return BuraScene(size: CGSize(width: 1024, height: 768))
        case .solitaire: return SolitaireScene(size: CGSize(width: 1024, height: 768))
        }
    }

    var body: some View {
        switch scenario.type {
        case .solitaire:
            // Solitaire has its own SwiftUI host (stable scene + cross-platform seed-entry alert).
            SolitaireHostView()
        default:
            GameSceneHost(scene: makeScene())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(scenario.title)
        }
    }
}

#Preview("Landing Page") {
    LandingPageView()
}
