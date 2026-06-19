import SwiftUI

@main
struct StorageOptimizerApp: App {
    // Hosts the Finder "Analyze with Storage Optimizer" Service provider (registered
    // in applicationDidFinishLaunching). See FinderService.swift.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
