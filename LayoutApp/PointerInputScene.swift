//
//  PointerInputScene.swift
//  LayoutApp
//
//  Cross-platform pointer input for SKScene subclasses. macOS mouse events and iOS/tvOS touches are both
//  funneled into the same overridable hooks (in scene-space coordinates), so each scene implements input
//  once instead of forking per platform. Subclasses override the `pointer*` methods; platform bridging
//  lives here.
//

import SpriteKit
#if canImport(UIKit)
import UIKit
#endif

class PointerInputScene: SKScene {

    /// Safe-area insets (points) set by the SwiftUI host when the board is full-screen, so edge UI (top bar,
    /// hand, chrome) can be kept clear of the notch / Dynamic Island / home indicator. Left/right matter in
    /// landscape (the island is on a side). Setting them re-lays-out.
    var topSafeInset: CGFloat = 0 { didSet { if oldValue != topSafeInset, size.width > 0 { didChangeSize(size) } } }
    var bottomSafeInset: CGFloat = 0 { didSet { if oldValue != bottomSafeInset, size.width > 0 { didChangeSize(size) } } }
    var leftSafeInset: CGFloat = 0 { didSet { if oldValue != leftSafeInset, size.width > 0 { didChangeSize(size) } } }
    var rightSafeInset: CGFloat = 0 { didSet { if oldValue != rightSafeInset, size.width > 0 { didChangeSize(size) } } }

    /// A press/click began at `point`. `tapCount` is the click/tap count (2 = double-click / double-tap).
    func pointerDown(at point: CGPoint, tapCount: Int) {}
    /// The active press/drag moved to `point`.
    func pointerMoved(to point: CGPoint) {}
    /// The active press/click ended at `point`.
    func pointerUp(at point: CGPoint) {}
    /// A secondary action — right-click on macOS (long-press on touch is not bridged yet).
    func pointerSecondary(at point: CGPoint) {}

    #if os(macOS)
    override func mouseDown(with event: NSEvent) { pointerDown(at: event.location(in: self), tapCount: event.clickCount) }
    override func mouseDragged(with event: NSEvent) { pointerMoved(to: event.location(in: self)) }
    override func mouseUp(with event: NSEvent) { pointerUp(at: event.location(in: self)) }
    override func rightMouseDown(with event: NSEvent) { pointerSecondary(at: event.location(in: self)) }
    #else
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        pointerDown(at: touch.location(in: self), tapCount: touch.tapCount)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        pointerMoved(to: touch.location(in: self))
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        pointerUp(at: touch.location(in: self))
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        pointerUp(at: touch.location(in: self))
    }
    #endif
}
