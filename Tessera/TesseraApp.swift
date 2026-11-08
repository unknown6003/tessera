import SwiftUI

@main
struct TesseraApp: App {
    // Hosts the Finder "Analyze with Tessera" Service provider (registered
    // in applicationDidFinishLaunching). See FinderService.swift.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // Fully automatic Sparkle OTA updates — checks, downloads, installs and
    // relaunches on its own. See Updater.swift.
    @StateObject private var updater = UpdaterController()

    var body: some Scene {
        WindowGroup("Tessera") {
            ContentView()
                .environmentObject(updater)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1240, height: 800)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            // Updates are automatic; this just skips the wait for the next
            // scheduled check. Its title doubles as the updater's status.
            CommandGroup(after: .appInfo) {
                Button(updater.status.menuTitle) { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates || updater.status.isBusy)
            }
        }

        // Settings… (⌘,). The analytics view and its storage belong to
        // Tessera/Analytics; this scene only hosts it.
        Settings {
            AnalyticsSettingsView()
                .tint(Theme.electricBlue)
                .preferredColorScheme(.dark)
        }
    }
}
