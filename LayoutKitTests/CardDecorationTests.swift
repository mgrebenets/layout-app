//
//  CardDecorationTests.swift
//  LayoutKitTests
//
//  Renders CardTableNode to a bitmap and checks the click-to-select affordances: a highlighted card
//  gains a teal outline, and a selected card gains a yellow outline and lifts up the screen. These
//  guard the reusable selection visuals used by the Durak input UX.
//

import Foundation
import Testing
import SpriteKit
@testable import LayoutKit

#if os(macOS)
import AppKit

@MainActor
@Suite("Card decoration")
struct CardDecorationTests {

    private let size = CGSize(width: 200, height: 240)

    @Test("Highlighting a card draws a teal outline")
    func highlightDrawsTealOutline() {
        let plain = bitmap(highlighted: false, selected: false)
        let lit = bitmap(highlighted: true, selected: false)
        #expect(tealPixelCount(plain) < 20)        // a plain card has no teal
        #expect(tealPixelCount(lit) > 60)          // the highlighted one is outlined teal
    }

    @Test("Selecting a card draws a yellow outline and lifts it up")
    func selectedDrawsYellowOutlineAndLifts() {
        let plain = bitmap(highlighted: false, selected: false)
        let chosen = bitmap(highlighted: false, selected: true)
        #expect(yellowPixelCount(plain) < 20)
        #expect(yellowPixelCount(chosen) > 60)
        // The lifted card's white body sits higher on screen → a smaller mean row index.
        #expect(meanWhiteRow(chosen) < meanWhiteRow(plain) - 6)
    }

    // MARK: - Rendering / pixel helpers

    private func bitmap(highlighted: Bool, selected: Bool) -> Pixels {
        let table = CardTableNode()
        table.faceProvider = { _ in CardFaceView(text: "A♠", isRed: false) }
        table.apply([0: CardPlacement(position: CGPoint(x: size.width / 2, y: size.height / 2),
                                      size: CGSize(width: 90, height: 126),
                                      faceUp: true, highlighted: highlighted, selected: selected)],
                    duration: 0) {}
        return render(table)
    }

    private struct Pixels { var data: [UInt8]; var width: Int; var height: Int }

    private func render(_ node: SKNode) -> Pixels {
        let scene = SKScene(size: size)
        scene.backgroundColor = SKColor(red: 0.10, green: 0.30, blue: 0.22, alpha: 1.0)
        scene.anchorPoint = .zero
        scene.addChild(node)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.presentScene(scene)
        guard let texture = view.texture(from: scene) else { fatalError("Failed to render scene") }
        let image = texture.cgImage()
        let width = image.width, height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return Pixels(data: data, width: width, height: height)
    }

    private func tealPixelCount(_ p: Pixels) -> Int {
        count(p) { r, g, b in r < 120 && g > 120 && b > 120 }
    }

    private func yellowPixelCount(_ p: Pixels) -> Int {
        count(p) { r, g, b in r > 180 && g > 150 && b < 120 }
    }

    private func count(_ p: Pixels, where match: (UInt8, UInt8, UInt8) -> Bool) -> Int {
        var n = 0, i = 0
        while i < p.data.count {
            if match(p.data[i], p.data[i + 1], p.data[i + 2]) { n += 1 }
            i += 4
        }
        return n
    }

    /// Average image row (0 = top) of the white card body — smaller means higher on screen.
    private func meanWhiteRow(_ p: Pixels) -> Double {
        var sum = 0, n = 0
        for row in 0..<p.height {
            for col in 0..<p.width {
                let i = (row * p.width + col) * 4
                if p.data[i] > 220, p.data[i + 1] > 220, p.data[i + 2] > 220 { sum += row; n += 1 }
            }
        }
        return n == 0 ? 0 : Double(sum) / Double(n)
    }
}
#endif
