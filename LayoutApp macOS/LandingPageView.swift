import SwiftUI
import SpriteKit
import LayoutKit

struct LandingPageView: View {
    let scenarios = [
        Scenario(title: "Overview", description: "Full layout system demonstration", type: .overview),
        Scenario(title: "War", description: "Play the War card game end-to-end on the GameEngine", type: .war)
    ]

    var body: some View {
        NavigationStack {
            List(scenarios) { scenario in
                NavigationLink(destination: ScenarioDetailView(scenario: scenario)) {
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
            .navigationTitle("Layout Scenarios")
        }
    }
}

struct ScenarioDetailView: View {
    let scenario: Scenario
    @StateObject private var contextMenuState = ContextMenuState()

    /// Layout scenarios share `LayoutScenarioScene`; the War scenario uses its own scene.
    private func makeScene() -> SKScene {
        switch scenario.type {
        case .war:
            return WarScene(size: CGSize(width: 1024, height: 768))
        default:
            return LayoutScenarioScene.create(for: scenario, contextMenuState: contextMenuState)
        }
    }

    var body: some View {
        ZStack {
            SpriteView(scene: makeScene())
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(scenario.title)
        }
        .popover(isPresented: $contextMenuState.showStackMenu, arrowEdge: .bottom) {
            if let config = contextMenuState.stackConfig, let index = contextMenuState.selectedIndex {
                StackLayoutMenu(
                    alignment: config.alignment,
                    zOrder: config.zOrder,
                    gapPercentage: config.gapPercentage,
                    itemSizing: config.itemSizing,
                    itemCount: config.itemCount,
                    onAlignmentChange: { newAlignment in
                        contextMenuState.onStackAlignmentChange?(index, newAlignment)
                        contextMenuState.showStackMenu = false
                    },
                    onGapPercentageChange: { newGap in
                        contextMenuState.onStackGapChange?(index, newGap)
                    },
                    onZOrderChange: { newZOrder in
                        contextMenuState.onStackZOrderChange?(index, newZOrder)
                        contextMenuState.showStackMenu = false
                    },
                    onItemCountChange: { newCount in
                        contextMenuState.onStackItemCountChange?(index, newCount)
                    },
                    onItemSizingChange: { newSizing in
                        contextMenuState.onStackItemSizingChange?(index, newSizing)
                    }
                )
                .frame(width: 280, height: 550)
            }
        }
        .popover(isPresented: $contextMenuState.showDiagonalMenu, arrowEdge: .bottom) {
            if let config = contextMenuState.diagonalConfig {
                DiagonalLayoutMenu(
                    horizontalAlignment: config.horizontalAlignment,
                    verticalAlignment: config.verticalAlignment,
                    horizontalGapPercentage: config.horizontalGapPercentage,
                    verticalGapPercentage: config.verticalGapPercentage,
                    zOrder: config.zOrder,
                    itemSizing: config.itemSizing,
                    itemCount: config.itemCount,
                    onHorizontalAlignmentChange: { newAlignment in
                        contextMenuState.onDiagonalHorizontalAlignmentChange?(newAlignment)
                        contextMenuState.showDiagonalMenu = false
                    },
                    onVerticalAlignmentChange: { newAlignment in
                        contextMenuState.onDiagonalVerticalAlignmentChange?(newAlignment)
                        contextMenuState.showDiagonalMenu = false
                    },
                    onHorizontalGapChange: { newGap in
                        contextMenuState.onDiagonalHorizontalGapChange?(newGap)
                    },
                    onVerticalGapChange: { newGap in
                        contextMenuState.onDiagonalVerticalGapChange?(newGap)
                    },
                    onZOrderChange: { newZOrder in
                        contextMenuState.onDiagonalZOrderChange?(newZOrder)
                        contextMenuState.showDiagonalMenu = false
                    },
                    onItemCountChange: { newCount in
                        contextMenuState.onDiagonalItemCountChange?(newCount)
                    },
                    onItemSizingChange: { newSizing in
                        contextMenuState.onDiagonalItemSizingChange?(newSizing)
                    }
                )
                .frame(width: 280, height: 550)
            }
        }
        .popover(isPresented: $contextMenuState.showCircularMenu, arrowEdge: .bottom) {
            if let config = contextMenuState.circularConfig {
                CircularLayoutMenu(
                    startAnglePercentage: config.startAnglePercentage,
                    radiusGapPercentage: config.radiusGapPercentage,
                    zOrder: config.zOrder,
                    itemSizing: config.itemSizing,
                    itemCount: config.itemCount,
                    onItemCountChange: { newCount in
                        contextMenuState.onCircularItemCountChange?(newCount)
                    },
                    onStartAngleChange: { newAngle in
                        contextMenuState.onCircularStartAngleChange?(newAngle)
                    },
                    onRadiusGapChange: { newGap in
                        contextMenuState.onCircularRadiusGapChange?(newGap)
                    },
                    onItemSizingChange: { newSizing in
                        contextMenuState.onCircularItemSizingChange?(newSizing)
                    },
                    onZOrderChange: { newZOrder in
                        contextMenuState.onCircularZOrderChange?(newZOrder)
                        contextMenuState.showCircularMenu = false
                    }
                )
                .frame(width: 280, height: 400)
            }
        }
        .popover(isPresented: $contextMenuState.showGridMenu, arrowEdge: .bottom) {
            if let config = contextMenuState.gridConfig {
                DynamicGridLayoutMenu(
                    horizontalAlignment: config.horizontalAlignment,
                    verticalAlignment: config.verticalAlignment,
                    horizontalGapPercentage: config.horizontalGapPercentage,
                    verticalGapPercentage: config.verticalGapPercentage,
                    zOrder: config.zOrder,
                    itemSizing: config.itemSizing,
                    itemCount: config.itemCount,
                    onHorizontalAlignmentChange: { newAlignment in
                        contextMenuState.onGridHorizontalAlignmentChange?(newAlignment)
                        contextMenuState.showGridMenu = false
                    },
                    onVerticalAlignmentChange: { newAlignment in
                        contextMenuState.onGridVerticalAlignmentChange?(newAlignment)
                        contextMenuState.showGridMenu = false
                    },
                    onHorizontalGapChange: { newGap in
                        contextMenuState.onGridHorizontalGapChange?(newGap)
                    },
                    onVerticalGapChange: { newGap in
                        contextMenuState.onGridVerticalGapChange?(newGap)
                    },
                    onZOrderChange: { newZOrder in
                        contextMenuState.onGridZOrderChange?(newZOrder)
                        contextMenuState.showGridMenu = false
                    },
                    onItemCountChange: { newCount in
                        contextMenuState.onGridItemCountChange?(newCount)
                    },
                    onItemSizingChange: { newSizing in
                        contextMenuState.onGridItemSizingChange?(newSizing)
                    }
                )
                .frame(width: 280, height: 600)
            }
        }
        .popover(isPresented: $contextMenuState.showCenterGridMenu, arrowEdge: .bottom) {
            if let config = contextMenuState.centerGridConfig {
                CenterGridLayoutMenu(
                    rows: config.rows,
                    columns: config.columns,
                    horizontalAlignment: config.horizontalAlignment,
                    verticalAlignment: config.verticalAlignment,
                    horizontalGapPercentage: config.horizontalGapPercentage,
                    verticalGapPercentage: config.verticalGapPercentage,
                    zOrder: config.zOrder,
                    itemSizing: config.itemSizing,
                    onRowsChange: { newRows in
                        contextMenuState.onCenterGridRowsChange?(newRows)
                    },
                    onColumnsChange: { newColumns in
                        contextMenuState.onCenterGridColumnsChange?(newColumns)
                    },
                    onHorizontalAlignmentChange: { newAlignment in
                        contextMenuState.onCenterGridHorizontalAlignmentChange?(newAlignment)
                        contextMenuState.showCenterGridMenu = false
                    },
                    onVerticalAlignmentChange: { newAlignment in
                        contextMenuState.onCenterGridVerticalAlignmentChange?(newAlignment)
                        contextMenuState.showCenterGridMenu = false
                    },
                    onHorizontalGapChange: { newGap in
                        contextMenuState.onCenterGridHorizontalGapChange?(newGap)
                    },
                    onVerticalGapChange: { newGap in
                        contextMenuState.onCenterGridVerticalGapChange?(newGap)
                    },
                    onZOrderChange: { newZOrder in
                        contextMenuState.onCenterGridZOrderChange?(newZOrder)
                        contextMenuState.showCenterGridMenu = false
                    },
                    onItemSizingChange: { newSizing in
                        contextMenuState.onCenterGridItemSizingChange?(newSizing)
                    }
                )
                .frame(width: 280, height: 650)
            }
        }
    }
}

// Observable object to bridge SpriteKit events to SwiftUI
public class ContextMenuState: ObservableObject {
    @Published var showStackMenu = false
    @Published var showDiagonalMenu = false
    @Published var showCircularMenu = false
    @Published var showGridMenu = false
    @Published var showCenterGridMenu = false

    @Published var stackConfig: LayoutConfiguration?
    @Published var diagonalConfig: DiagonalConfiguration?
    @Published var circularConfig: CircularConfiguration?
    @Published var gridConfig: GridConfiguration?
    @Published var centerGridConfig: CenterGridConfiguration?

    @Published var selectedIndex: Int?

    // Callbacks that the scene will set
    var onStackAlignmentChange: ((Int, Alignment) -> Void)?
    var onStackGapChange: ((Int, CGFloat) -> Void)?
    var onStackZOrderChange: ((Int, ZOrder) -> Void)?
    var onStackItemCountChange: ((Int, Int) -> Void)?
    var onStackItemSizingChange: ((Int, RelativeSizing) -> Void)?

    var onDiagonalHorizontalAlignmentChange: ((Alignment) -> Void)?
    var onDiagonalVerticalAlignmentChange: ((Alignment) -> Void)?
    var onDiagonalHorizontalGapChange: ((CGFloat) -> Void)?
    var onDiagonalVerticalGapChange: ((CGFloat) -> Void)?
    var onDiagonalZOrderChange: ((ZOrder) -> Void)?
    var onDiagonalItemCountChange: ((Int) -> Void)?
    var onDiagonalItemSizingChange: ((RelativeSizing) -> Void)?

    var onCircularItemCountChange: ((Int) -> Void)?
    var onCircularStartAngleChange: ((CGFloat) -> Void)?
    var onCircularRadiusGapChange: ((CGFloat) -> Void)?
    var onCircularItemSizingChange: ((RelativeSizing) -> Void)?
    var onCircularZOrderChange: ((ZOrder) -> Void)?

    var onGridHorizontalAlignmentChange: ((Alignment) -> Void)?
    var onGridVerticalAlignmentChange: ((Alignment) -> Void)?
    var onGridHorizontalGapChange: ((CGFloat) -> Void)?
    var onGridVerticalGapChange: ((CGFloat) -> Void)?
    var onGridZOrderChange: ((ZOrder) -> Void)?
    var onGridItemCountChange: ((Int) -> Void)?
    var onGridItemSizingChange: ((RelativeSizing) -> Void)?

    var onCenterGridRowsChange: ((Int) -> Void)?
    var onCenterGridColumnsChange: ((Int) -> Void)?
    var onCenterGridHorizontalAlignmentChange: ((Alignment) -> Void)?
    var onCenterGridVerticalAlignmentChange: ((Alignment) -> Void)?
    var onCenterGridHorizontalGapChange: ((CGFloat) -> Void)?
    var onCenterGridVerticalGapChange: ((CGFloat) -> Void)?
    var onCenterGridZOrderChange: ((ZOrder) -> Void)?
    var onCenterGridItemSizingChange: ((RelativeSizing) -> Void)?
}

#Preview("Landing Page") {
    LandingPageView()
}

#Preview("Scenario Detail") {
    ScenarioDetailView(scenario: Scenario(title: "Overview", description: "Full layout system", type: .overview))
}
