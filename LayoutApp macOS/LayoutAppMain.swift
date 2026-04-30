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
                .frame(minWidth: 800, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            // Remove "New Window" menu item since we only want one window
            CommandGroup(replacing: .newItem) { }
        }
    }
}
