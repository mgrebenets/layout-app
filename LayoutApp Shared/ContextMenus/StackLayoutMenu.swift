//
//  StackLayoutMenu.swift
//  LayoutApp macOS
//

import SwiftUI
import LayoutKit

struct StackLayoutMenu: View {
    let alignment: Alignment
    let zOrder: ZOrder
    let gapPercentage: CGFloat
    let itemSizing: RelativeSizing
    let itemCount: Int

    let onAlignmentChange: (Alignment) -> Void
    let onGapPercentageChange: (CGFloat) -> Void
    let onZOrderChange: (ZOrder) -> Void
    let onItemCountChange: (Int) -> Void
    let onItemSizingChange: (RelativeSizing) -> Void

    @State private var gapPercentageState: Double
    @State private var itemCountState: Double
    @State private var widthBaseDimension: String = "Container Width"
    @State private var widthPercentage: Double
    @State private var heightBaseDimension: String = "Container Height"
    @State private var heightPercentage: Double

    init(
        alignment: Alignment,
        zOrder: ZOrder,
        gapPercentage: CGFloat,
        itemSizing: RelativeSizing,
        itemCount: Int,
        onAlignmentChange: @escaping (Alignment) -> Void,
        onGapPercentageChange: @escaping (CGFloat) -> Void,
        onZOrderChange: @escaping (ZOrder) -> Void,
        onItemCountChange: @escaping (Int) -> Void,
        onItemSizingChange: @escaping (RelativeSizing) -> Void
    ) {
        self.alignment = alignment
        self.zOrder = zOrder
        self.gapPercentage = gapPercentage
        self.itemSizing = itemSizing
        self.itemCount = itemCount
        self.onAlignmentChange = onAlignmentChange
        self.onGapPercentageChange = onGapPercentageChange
        self.onZOrderChange = onZOrderChange
        self.onItemCountChange = onItemCountChange
        self.onItemSizingChange = onItemSizingChange

        self._gapPercentageState = State(initialValue: Double(gapPercentage))
        self._itemCountState = State(initialValue: Double(itemCount))
        self._widthPercentage = State(initialValue: Double(itemSizing.containerPercentage))
        self._heightPercentage = State(initialValue: Double(itemSizing.containerPercentage))
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Stack Layout")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Alignment")
                            .font(.subheadline)

                        HStack(spacing: 12) {
                            Button("Leading") {
                                onAlignmentChange(.leading)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(alignment == .leading ? .blue : .primary)

                            Button("Center") {
                                onAlignmentChange(.center)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(alignment == .center ? .blue : .primary)

                            Button("Trailing") {
                                onAlignmentChange(.trailing)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(alignment == .trailing ? .blue : .primary)
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
                        Text("Gap Percentage")
                            .font(.subheadline)

                        HStack {
                            Text("-3.0")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Slider(value: $gapPercentageState, in: -3.0...3.0, step: 0.1)
                                .onChange(of: gapPercentageState) { _, newValue in
                                    onGapPercentageChange(CGFloat(newValue))
                                }

                            Text("3.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text(String(format: "%.1f", gapPercentageState))
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

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Item Count")
                            .font(.subheadline)

                        HStack {
                            Text("1")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Slider(value: $itemCountState, in: 1...10, step: 1)
                                .onChange(of: itemCountState) { _, newValue in
                                    onItemCountChange(Int(newValue))
                                }

                            Text("10")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text("\(Int(itemCountState))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
        }
        .frame(width: 280, height: 550, alignment: .center)
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
