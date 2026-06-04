//
//  CardOcclusionTests.swift
//  LayoutKitTests
//
//  Renders CardTableNode to a bitmap and checks z-layering: a front card must occlude the card
//  behind it (no pip "leak"). This guards the SpriteKit additive-zPosition gotcha that made back
//  cards' labels bleed over front cards' bodies.
//

import Foundation
import Testing
import SpriteKit
@testable import LayoutKit

#if os(macOS)
import AppKit

@MainActor
@Suite("Card occlusion")
struct CardOcclusionTests {

    @Test("A front card occludes the card behind it (no pip leak)")
    func frontOccludesBack() {
        let size = CGSize(width: 240, height: 240)
        let center = CGPoint(x: 120, y: 120)

        // A red card on its own — its pips/label are visible.
        let alone = CardTableNode()
        alone.faceProvider = { _ in CardFaceView(text: "A♥", isRed: true) }
        alone.apply([0: CardPlacement(position: center, zPosition: 0, faceUp: true)], duration: 0) {}
        let redAlone = redPixelCount(render(alone, size: size))
        #expect(redAlone > 50) // sanity: the red card actually drew red

        // A black card laid fully over the red one must hide almost all of that red.
        let covered = CardTableNode()
        covered.faceProvider = { id in
            id == 0 ? CardFaceView(text: "A♥", isRed: true) : CardFaceView(text: "K♠", isRed: false)
        }
        covered.apply([
            0: CardPlacement(position: center, zPosition: 0, faceUp: true),
            1: CardPlacement(position: center, zPosition: 1, faceUp: true),
        ], duration: 0) {}
        let redCovered = redPixelCount(render(covered, size: size))

        #expect(redCovered < redAlone / 5) // the front (black) card occludes the back card's red pips
    }

    // MARK: - Rendering / pixel helpers

    private func render(_ node: SKNode, size: CGSize) -> CGImage {
        let scene = SKScene(size: size)
        scene.backgroundColor = SKColor(red: 0.10, green: 0.30, blue: 0.22, alpha: 1.0)
        scene.anchorPoint = .zero
        scene.addChild(node)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.presentScene(scene)
        guard let texture = view.texture(from: scene) else {
            fatalError("Failed to render scene to a texture")
        }
        return texture.cgImage()
    }

    private func redPixelCount(_ image: CGImage) -> Int {
        let width = image.width, height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var count = 0
        var i = 0
        while i < data.count {
            if data[i] > 150, data[i + 1] < 100, data[i + 2] < 100 { count += 1 } // strongly red
            i += 4
        }
        return count
    }
}
#endif
