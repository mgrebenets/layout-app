//
//  DurakHostView.swift
//  LayoutApp
//
//  Full-screen SwiftUI host for the Durak board. The SpriteKit scene fills the whole screen (under the
//  notch / home indicator); the only SwiftUI chrome is a translucent back button and a gear that opens the
//  debug/settings sheet. Rules and the deal seed live in that sheet (styled to match the felt), not on the
//  board. Reusable pattern for the other games.
//

import SwiftUI
import SpriteKit
import GameEngine

/// The green felt, matched to the Durak scene's background, so SwiftUI chrome reads as part of the game.
private let feltGreen = Color(red: 0.10, green: 0.30, blue: 0.22)

@MainActor
final class DurakHost: ObservableObject {
    let scene = DurakScene(size: CGSize(width: 1024, height: 768))
    @Published var showSettings = false
}

struct DurakHostView: View {
    let onClose: () -> Void
    @StateObject private var host = DurakHost()

    var body: some View {
        GameSceneHost(scene: host.scene, fullScreen: true)
            .onAppear {
                host.scene.onBack = onClose
                host.scene.onOpenSettings = { host.showSettings = true }
            }
            .sheet(isPresented: $host.showSettings) { DurakSettingsView(scene: host.scene) }
    }
}

/// Debug/settings for Durak — edit rules and deal a specific seed. Styled to match the felt. Reads the
/// scene's current config on present; the ✓ button (or a deal button) restarts the match with the settings.
struct DurakSettingsView: View {
    let scene: DurakScene
    @Environment(\.dismiss) private var dismiss

    @State private var playerCount: Int
    @State private var teaching: Bool
    @State private var lossLimit: Int
    @State private var allowThrowIn: Bool
    @State private var throwInOnTake: Bool
    @State private var principalPriority: Bool
    @State private var firstAttackMaxFive: Bool
    @State private var seedText: String

    init(scene: DurakScene) {
        self.scene = scene
        let r = scene.currentRules
        _playerCount = State(initialValue: scene.currentPlayerCount)
        _teaching = State(initialValue: scene.currentTeaching)
        _lossLimit = State(initialValue: scene.currentLossLimit)
        _allowThrowIn = State(initialValue: r.allowThrowIn)
        _throwInOnTake = State(initialValue: r.throwInOnTake)
        _principalPriority = State(initialValue: r.throwInPriority == .principalFirst)
        _firstAttackMaxFive = State(initialValue: r.firstAttackMaxFive)
        _seedText = State(initialValue: String(scene.currentSeed))
    }

    private func makeRules() -> DurakRules {
        DurakRules(handSize: scene.currentRules.handSize,
                   lowestRank: scene.currentRules.lowestRank,
                   allowThrowIn: allowThrowIn,
                   throwInOnTake: throwInOnTake,
                   throwInPriority: principalPriority ? .principalFirst : .roundRobin,
                   firstAttackMaxFive: firstAttackMaxFive)
    }

    private func applyAndDeal() {
        scene.applyConfig(playerCount: playerCount, rules: makeRules(), lossLimit: lossLimit, teaching: teaching)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Table") {
                    Stepper("Players: \(playerCount)", value: $playerCount, in: 2...4)
                    Toggle("Teaching the durak", isOn: $teaching)
                    Picker("Lose at", selection: $lossLimit) {
                        Text("∞").tag(0)
                        ForEach(1...6, id: \.self) { Text("\($0) losses").tag($0) }
                    }
                }
                .listRowBackground(Color.white.opacity(0.10))

                Section("Throw-in rules") {
                    Toggle("Allow throw-in", isOn: $allowThrowIn)
                    Toggle("Throw in while taking", isOn: $throwInOnTake)
                    Toggle("Principal attacker priority", isOn: $principalPriority)
                    Toggle("First attack capped at 5", isOn: $firstAttackMaxFive)
                }
                .listRowBackground(Color.white.opacity(0.10))

                Section {
                    LabeledContent {
                        TextField("Seed", text: $seedText)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Label("Seed", systemImage: "die.face.5")
                    }
                    Button("Deal this seed") {
                        if let value = UInt64(seedText.trimmingCharacters(in: .whitespaces)) { scene.dealSeed(value) }
                        dismiss()
                    }
                    Button("New random deal") { applyAndDeal(); dismiss() }
                } header: {
                    Text("Deal")
                } footer: {
                    Text("The same seed always deals the same game.")
                }
                .listRowBackground(Color.white.opacity(0.10))
            }
            .scrollContentBackground(.hidden)
            .background(feltGreen.ignoresSafeArea())
            .foregroundStyle(.white)
            .tint(.teal)
            .navigationTitle("Durak — Debug")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(feltGreen, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { applyAndDeal(); dismiss() } label: { Image(systemName: "checkmark") }
                }
            }
        }
    }
}
