import SwiftUI

@main
struct TesseraApp: App {
    // Hosts the Finder "Analyze with Tessera" Service provider (registered
    // in applicationDidFinishLaunching). See FinderService.swift.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // Sparkle OTA auto-updates (direct distribution — see Updater.swift).
    @StateObject private var updater = UpdaterController()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {}
            // Standard "Check for Updates…" in the app menu, just below About.
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            }
        }
    }
}
