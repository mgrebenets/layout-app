//
//  SolitaireHostView.swift
//  LayoutApp macOS
//
//  SwiftUI host for the Solitaire scene. The SpriteKit scene stays platform-agnostic (it just renders and
//  reports events); anything that needs native chrome — here, entering a seed — is presented in SwiftUI so
//  it ports to iOS/iPadOS unchanged. The scene is held by a `@StateObject` so it survives body re-renders
//  (toggling the alert must not re-deal the game).
//

import SwiftUI
import SpriteKit

@MainActor
final class SolitaireHost: ObservableObject {
    let scene: SolitaireScene
    @Published var showSeedPrompt = false
    @Published var seedText = ""

    init() {
        scene = SolitaireScene(size: CGSize(width: 1024, height: 768))
        scene.onRequestSeedEntry = { [weak self] in
            guard let self else { return }
            seedText = String(scene.currentSeed)
            showSeedPrompt = true
        }
    }

    func dealEnteredSeed() {
        guard let value = UInt64(seedText.trimmingCharacters(in: .whitespaces)) else { return }
        scene.dealGame(seed: value)
    }
}

struct SolitaireHostView: View {
    @StateObject private var host = SolitaireHost()

    var body: some View {
        GameSceneHost(scene: host.scene)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Solitaire")
            .alert("Deal a specific game", isPresented: $host.showSeedPrompt) {
                TextField("Seed", text: $host.seedText)
                #if os(iOS)
                    .keyboardType(.numberPad)
                #endif
                Button("Deal") { host.dealEnteredSeed() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The same seed always deals the same layout.")
            }
    }
}
