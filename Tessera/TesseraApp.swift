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
        WindowGroup {
            ContentView()
                .environmentObject(updater)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {}
            // Updates are automatic; this just skips the wait for the next
            // scheduled check. Its title doubles as the updater's status.
            CommandGroup(after: .appInfo) {
                Button(updater.status.menuTitle) { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates || updater.status.isBusy)
            }
        }
    }
}
