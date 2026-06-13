//
//  GameSceneHost.swift
//  LayoutApp
//
//  Hosts an SKScene at exactly the available size. SwiftUI's `SpriteView` does not reliably resize a
//  `.resizeFill` scene to the view on iOS, so a landscape-authored scene (1024×768) gets squished into a
//  portrait phone frame — anamorphic stretch. Pinning `scene.size` to the measured size keeps it 1:1.
//
//  When `fullScreen`, the board fills the whole screen and the device's safe-area insets are forwarded to
//  the scene so it can keep its interactive edge UI clear of the notch / Dynamic Island / home indicator.
//  Insets come from a full-bleed UIKit probe (`SafeAreaReader`) via `safeAreaInsetsDidChange()`, which fires
//  with correct per-side values on every change — including landscape-left ↔ landscape-right, where the size
//  doesn't change and `GeometryProxy.safeAreaInsets` reports 0 once safe area is ignored.
//

import SwiftUI
import SpriteKit
#if canImport(UIKit)
import UIKit
#endif

struct GameSceneHost: View {
    let scene: SKScene
    var fullScreen = false

    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: scene)
                .onAppear { scene.size = geo.size }
                .onChange(of: geo.size) { _, newSize in scene.size = newSize }
                #if canImport(UIKit)
                .background(SafeAreaReader { insets in apply(insets) })
                #endif
        }
        .ignoresSafeArea(edges: fullScreen ? .all : [])
    }

    #if canImport(UIKit)
    private func apply(_ insets: UIEdgeInsets) {
        guard fullScreen, let s = scene as? PointerInputScene else { return }
        s.topSafeInset = insets.top
        s.bottomSafeInset = insets.bottom
        s.leftSafeInset = insets.left
        s.rightSafeInset = insets.right
    }
    #endif
}

#if canImport(UIKit)
/// A transparent, full-bleed UIKit view that reports the live safe-area insets. `safeAreaInsetsDidChange`
/// fires with correct per-side values whenever they change (rotation, including landscape ↔ landscape).
private struct SafeAreaReader: UIViewRepresentable {
    let onChange: (UIEdgeInsets) -> Void

    func makeUIView(context: Context) -> InsetReportingView {
        let view = InsetReportingView()
        view.onChange = onChange
        return view
    }
    func updateUIView(_ uiView: InsetReportingView, context: Context) { uiView.onChange = onChange }

    final class InsetReportingView: UIView {
        var onChange: ((UIEdgeInsets) -> Void)?
        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            onChange?(safeAreaInsets)
        }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onChange?(self.safeAreaInsets)
            }
        }
    }
}
#endif
