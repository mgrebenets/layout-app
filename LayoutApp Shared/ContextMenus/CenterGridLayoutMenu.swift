//
//  CenterGridLayoutMenu.swift
//  LayoutApp macOS
//

import SwiftUI
import LayoutKit

typealias Alignment = LayoutKit.Alignment

struct CenterGridLayoutMenu: View {
    let rows: Int
    let columns: Int
    let horizontalAlignment: Alignment
    let verticalAlignment: Alignment
    let horizontalGapPercentage: CGFloat
    let verticalGapPercentage: CGFloat
    let zOrder: ZOrder
    let itemSizing: RelativeSizing

    let onRowsChange: (Int) -> Void
    let onColumnsChange: (Int) -> Void
    let onHorizontalAlignmentChange: (Alignment) -> Void
    let onVerticalAlignmentChange: (Alignment) -> Void
    let onHorizontalGapChange: (CGFloat) -> Void
    let onVerticalGapChange: (CGFloat) -> Void
    let onZOrderChange: (ZOrder) -> Void
    let onItemSizingChange: (RelativeSizing) -> Void

    @State private var rowsState: Double
    @State private var columnsState: Double
    @State private var horizontalGap: Double
    @State private var verticalGap: Double
    @State private var widthBaseDimension: String = "Container Width"
    @State private var widthPercentage: Double
    @State private var heightBaseDimension: String = "Container Height"
    @State private var heightPercentage: Double

    init(
        rows: Int,
        columns: Int,
        horizontalAlignment: Alignment,
        verticalAlignment: Alignment,
        horizontalGapPercentage: CGFloat,
        verticalGapPercentage: CGFloat,
        zOrder: ZOrder,
        itemSizing: RelativeSizing,
        onRowsChange: @escaping (Int) -> Void,
        onColumnsChange: @escaping (Int) -> Void,
        onHorizontalAlignmentChange: @escaping (Alignment) -> Void,
        onVerticalAlignmentChange: @escaping (Alignment) -> Void,
        onHorizontalGapChange: @escaping (CGFloat) -> Void,
        onVerticalGapChange: @escaping (CGFloat) -> Void,
        onZOrderChange: @escaping (ZOrder) -> Void,
        onItemSizingChange: @escaping (RelativeSizing) -> Void
    ) {
        self.rows = rows
        self.columns = columns
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.horizontalGapPercentage = horizontalGapPercentage
        self.verticalGapPercentage = verticalGapPercentage
        self.zOrder = zOrder
        self.itemSizing = itemSizing
        self.onRowsChange = onRowsChange
        self.onColumnsChange = onColumnsChange
        self.onHorizontalAlignmentChange = onHorizontalAlignmentChange
        self.onVerticalAlignmentChange = onVerticalAlignmentChange
        self.onHorizontalGapChange = onHorizontalGapChange
        self.onVerticalGapChange = onVerticalGapChange
        self.onZOrderChange = onZOrderChange
        self.onItemSizingChange = onItemSizingChange

        self._rowsState = State(initialValue: Double(rows))
        self._columnsState = State(initialValue: Double(columns))
        self._horizontalGap = State(initialValue: Double(horizontalGapPercentage))
        self._verticalGap = State(initialValue: Double(verticalGapPercentage))
        self._widthPercentage = State(initialValue: Double(itemSizing.containerPercentage))
        self._heightPercentage = State(initialValue: Double(itemSizing.containerPercentage))
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Center Grid Layout")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rows")
                            .font(.subheadline)

                        HStack {
                            Text("1")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Slider(value: $rowsState, in: 1...5, step: 1)
                                .onChange(of: rowsState) { _, newValue in
                                    onRowsChange(Int(newValue))
                                }

                            Text("5")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text("\(Int(rowsState))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Columns")
                            .font(.subheadline)

                        HStack {
                            Text("1")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Slider(value: $columnsState, in: 1...5, step: 1)
                                .onChange(of: columnsState) { _, newValue in
                                    onColumnsChange(Int(newValue))
                                }

                            Text("5")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text("\(Int(columnsState))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Horizontal Alignment")
                            .font(.subheadline)

                        HStack(spacing: 12) {
                            Button("Leading") {
                                onHorizontalAlignmentChange(.leading)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(horizontalAlignment == .leading ? .blue : .primary)

                            Button("Center") {
                                onHorizontalAlignmentChange(.center)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(horizontalAlignment == .center ? .blue : .primary)

                            Button("Trailing") {
                                onHorizontalAlignmentChange(.trailing)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(horizontalAlignment == .trailing ? .blue : .primary)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vertical Alignment")
                            .font(.subheadline)

                        HStack(spacing: 12) {
                            Button("Leading") {
                                onVerticalAlignmentChange(.leading)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(verticalAlignment == .leading ? .blue : .primary)

                            Button("Center") {
                                onVerticalAlignmentChange(.center)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(verticalAlignment == .center ? .blue : .primary)

                            Button("Trailing") {
                                onVerticalAlignmentChange(.trailing)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(verticalAlignment == .trailing ? .blue : .primary)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Z-Order")
                            .font(.subheadline)

                        HStack(spacing: 12) {
                            Button("Ascending") {
                                onZOrderChange(.ascending)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(zOrder == .ascending ? .blue : .primary)

                            Button("Descending") {
                                onZOrderChange(.descending)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(zOrder == .descending ? .blue : .primary)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Horizontal Gap")
                            .font(.subheadline)

                        HStack {
                            Text("0.0")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Slider(value: $horizontalGap, in: 0.0...3.0, step: 0.1)
                                .onChange(of: horizontalGap) { _, newValue in
                                    onHorizontalGapChange(CGFloat(newValue))
                                }

                            Text("3.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(String(format: "%.1f", horizontalGap))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vertical Gap")
                            .font(.subheadline)

                        HStack {
                            Text("0.0")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Slider(value: $verticalGap, in: 0.0...3.0, step: 0.1)
                                .onChange(of: verticalGap) { _, newValue in
                                    onVerticalGapChange(CGFloat(newValue))
                                }

                            Text("3.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(String(format: "%.1f", verticalGap))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Width Base Dimension")
                            .font(.subheadline)

                        Picker("", selection: $widthBaseDimension) {
                            Text("Container Width").tag("Container Width")
                            Text("Container Height").tag("Container Height")
                            Text("Container Smallest").tag("Container Smallest")
                            Text("Container Largest").tag("Container Largest")
                            Text("Item Height").tag("Item Height")
                        }
                        .pickerStyle(.menu)
                        .onChange(of: widthBaseDimension) {
                            updateAdvancedSizing()
                        }

                        Text("Width Percentage")
                            .font(.subheadline)
                            .padding(.top, 4)

                        HStack {
                            Text("0.1")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Slider(value: $widthPercentage, in: 0.1...2.0, step: 0.05)
                                .onChange(of: widthPercentage) {
                                    updateAdvancedSizing()
                                }

                            Text("2.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(String(format: "%.2f", widthPercentage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Height Base Dimension")
                            .font(.subheadline)

                        Picker("", selection: $heightBaseDimension) {
                            Text("Container Width").tag("Container Width")
                            Text("Container Height").tag("Container Height")
                            Text("Container Smallest").tag("Container Smallest")
                            Text("Container Largest").tag("Container Largest")
                            Text("Item Width").tag("Item Width")
                        }
                        .pickerStyle(.menu)
                        .onChange(of: heightBaseDimension) {
                            updateAdvancedSizing()
                        }

                        Text("Height Percentage")
                            .font(.subheadline)
                            .padding(.top, 4)

                        HStack {
                            Text("0.1")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Slider(value: $heightPercentage, in: 0.1...2.0, step: 0.05)
                                .onChange(of: heightPercentage) {
                                    updateAdvancedSizing()
                                }

                            Text("2.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(String(format: "%.2f", heightPercentage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
        }
        .frame(width: 280, height: 650, alignment: .center)
    }

    private func updateAdvancedSizing() {
        let widthSpec: RelativeSizing.DimensionSpec
        switch widthBaseDimension {
        case "Container Width":
            widthSpec = .containerWidth(percentage: CGFloat(widthPercentage))
        case "Container Height":
            widthSpec = .containerHeight(percentage: CGFloat(widthPercentage))
        case "Container Smallest":
            widthSpec = .containerSmallest(percentage: CGFloat(widthPercentage))
        case "Container Largest":
            widthSpec = .containerLargest(percentage: CGFloat(widthPercentage))
        case "Item Height":
            widthSpec = .itemHeight(percentage: CGFloat(widthPercentage))
        default:
            widthSpec = .containerWidth(percentage: CGFloat(widthPercentage))
        }

        let heightSpec: RelativeSizing.DimensionSpec
        switch heightBaseDimension {
        case "Container Width":
            heightSpec = .containerWidth(percentage: CGFloat(heightPercentage))
        case "Container Height":
            heightSpec = .containerHeight(percentage: CGFloat(heightPercentage))
        case "Container Smallest":
            heightSpec = .containerSmallest(percentage: CGFloat(heightPercentage))
        case "Container Largest":
            heightSpec = .containerLargest(percentage: CGFloat(heightPercentage))
        case "Item Width":
            heightSpec = .itemWidth(percentage: CGFloat(heightPercentage))
        default:
            heightSpec = .containerHeight(percentage: CGFloat(heightPercentage))
        }

        let newSizing = RelativeSizing(widthSpec: widthSpec, heightSpec: heightSpec)
        onItemSizingChange(newSizing)
    }
}
