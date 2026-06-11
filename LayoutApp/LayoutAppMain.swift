//
//  LayoutAppMain.swift
//  LayoutApp macOS
//
//  Pure SwiftUI entry point
//

import SwiftUI

@main
struct LayoutApp: App {
    var body: some Scene {
        WindowGroup {
            LandingPageView()
                #if os(macOS)
                .frame(minWidth: 800, minHeight: 600)  // window min size — macOS only; on iOS it would force an oversized root view
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)  // macOS/visionOS only
        #endif
        .commands {
            // Remove "New Window" menu item since we only want one window
            CommandGroup(replacing: .newItem) { }
        }
    }
}
