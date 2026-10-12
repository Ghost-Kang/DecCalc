import AppKit
import SwiftUI

@main
struct DecCalcApp: App {
    init() {
        if let index = CommandLine.arguments.firstIndex(of: "--snapshot"), index + 1 < CommandLine.arguments.count {
            Snapshot.render(to: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
            exit(0)
        }
        // Launched from `swift run`, the process needs to become a regular app.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("DecCalc") {
            ContentView()
                .fixedSize()
                .preferredColorScheme(.dark)
        }
        .windowResizability(.contentSize)
    }
}
