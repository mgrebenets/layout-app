//
//  LayoutConfigurations.swift
//  LayoutApp Shared
//
//  Created by Max Grebenets on 21/10/2025.
//

import Foundation
import LayoutKit

// Configuration structs for different layout types
public struct LayoutConfiguration {
    var axis: LayoutAxis
    var itemSizing: RelativeSizing
    var gapPercentage: CGFloat
    var alignment: Alignment
    var zOrder: ZOrder
    var rect: CGRect
    var itemCount: Int
}

public struct DiagonalConfiguration {
    var itemSizing: RelativeSizing
    var horizontalGapPercentage: CGFloat
    var verticalGapPercentage: CGFloat
    var horizontalAlignment: Alignment
    var verticalAlignment: Alignment
    var zOrder: ZOrder
    var rect: CGRect
    var itemCount: Int
}

public struct CircularConfiguration {
    var itemSizing: RelativeSizing
    var rect: CGRect
    var itemCount: Int
    var startAnglePercentage: CGFloat
    var radiusGapPercentage: CGFloat
    var zOrder: ZOrder
}

public struct GridConfiguration {
    var itemSizing: RelativeSizing
    var rect: CGRect
    var itemCount: Int
    var horizontalGapPercentage: CGFloat
    var verticalGapPercentage: CGFloat
    var horizontalAlignment: Alignment
    var verticalAlignment: Alignment
    var zOrder: ZOrder
}

public struct CenterGridConfiguration {
    var rows: Int
    var columns: Int
    var itemSizing: RelativeSizing
    var rect: CGRect
    var horizontalGapPercentage: CGFloat
    var verticalGapPercentage: CGFloat
    var horizontalAlignment: Alignment
    var verticalAlignment: Alignment
    var zOrder: ZOrder
}
