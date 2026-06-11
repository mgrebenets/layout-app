//
//  CardMetrics.swift
//  LayoutKit
//
//  Shared geometry for laying out cards. The one rule every scene needs is "how big a card fits here?" —
//  scale a card to the window without distorting it. Keeping it here means Solitaire, Durak, Bura, … all
//  scale cards the same way and stay visually consistent.
//

import CoreGraphics

public enum CardMetrics {

    /// Playing-card aspect as height ÷ width — the 78×108 baseline the card art (`CardNode`) is tuned for.
    public static let aspect: CGFloat = 108.0 / 78.0

    /// The largest card (keeping `aspect`) that fits within both a width and a height budget. Pass the space
    /// a single card may occupy on each axis; the tighter constraint wins. This is the rule the scenes use to
    /// scale cards with the window — bigger window, bigger cards, never stretched.
    public static func fit(maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        let width = max(1, min(maxWidth, maxHeight / aspect))
        return CGSize(width: width, height: width * aspect)
    }
}
