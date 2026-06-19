import SwiftUI
import AppKit

/// Finder integration — "Analyze with Storage Optimizer".
///
/// This is implemented as a macOS **Services** entry (declared under `NSServices`
/// in Info.plist), NOT a Finder Sync extension. A true contextual right-click item
/// at the top of Finder's menu would require a separate Finder Sync (`.appex`)
/// extension target, which a plain `.xcodeproj` here can't add without becoming a
/// multi-target project. The Services approach is still reachable from a Finder
/// right-click: selecting a folder and using `Services ▸ Analyze with Storage
/// Optimizer` (and, once used, it can be promoted to the top level via System
/// Settings ▸ Keyboard ▸ Keyboard Shortcuts ▸ Services). It also appears in the
/// app menu's Services submenu. This keeps everything inside the single app target.
///
/// Flow:
///   1. `Info.plist` declares the service (accepts `public.folder` /
///      `NSFilenamesPboardType`, no return type, selector `analyzeFolder:userData:error:`).
///   2. `AppDelegate` registers a `FinderServiceProvider` as `NSApp.servicesProvider`
///      on launch.
///   3. The provider resolves the dropped/selected folder path and routes it into
///      the app's single live `ScanViewModel` via `SharedScanContext`, which the
///      one `ContentView` publishes its view-model into.

/// A process-wide handle to the single live `ScanViewModel` owned by `ContentView`.
/// The Services provider runs outside SwiftUI's view graph, so it needs this bridge
/// to reach the app's one window/view-model. `ContentView` registers its VM here on
/// appear; the provider reads it back (on the main actor).
@MainActor
final class SharedScanContext {
    static let shared = SharedScanContext()
    private init() {}

    /// The live view-model for the app's single window. Weak so we never keep a
    /// dead VM alive; in practice `ContentView` owns it for the app's lifetime.
    weak var viewModel: ScanViewModel?

    /// A folder path that arrived (via the Service) before the VM was ready — e.g.
    /// when the Service launches a cold app. `ContentView` drains this on appear.
    var pendingScanPath: String?

    /// Route a folder path into the live VM, or stash it until the VM exists.
    func requestScan(path: String) {
        let url = URL(fileURLWithPath: path)
        if let vm = viewModel {
            vm.startScan(volumeURL: url)
        } else {
            pendingScanPath = path
        }
    }

    /// Called by `ContentView.onAppear`: registers the live VM and runs any scan
    /// that was requested before the window existed.
    func register(_ vm: ScanViewModel) {
        viewModel = vm
        if let path = pendingScanPath {
            pendingScanPath = nil
            vm.startScan(volumeURL: URL(fileURLWithPath: path))
        }
    }
}

/// Receives the macOS Service invocation. The selector name
/// (`analyzeFolder:userData:error:`) must match the `NSMessage` in Info.plist.
final class FinderServiceProvider: NSObject {
    /// Service handler. macOS calls this on the main thread with the folder(s) the
    /// user selected in Finder. We take the first folder and start a scan.
    ///
    /// Signature is the standard 3-argument Services shape:
    /// `(NSPasteboard, String userData, error: AutoreleasingUnsafeMutablePointer<NSString?>)`.
    @objc func analyzeFolder(_ pboard: NSPasteboard,
                             userData: String,
                             error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let path = Self.folderPath(from: pboard) else {
            error.pointee = "No folder was provided." as NSString
            return
        }

        // Bring the app forward so the scan is visible, then route the path into
        // the single live view-model. macOS invokes this selector on the main
        // thread, but the method isn't statically main-actor-isolated, so all the
        // AppKit/view-model work (which is main-actor-isolated) is hopped onto the
        // main actor explicitly.
        Task { @MainActor in
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { $0.isVisible }) ?? NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
            SharedScanContext.shared.requestScan(path: path)
        }
    }

    /// Pull a directory path off the Service pasteboard. Modern callers put file
    /// URLs on the board; the legacy `NSFilenamesPboardType` path covers older
    /// flows. We accept the first entry that is an existing directory.
    private static func folderPath(from pboard: NSPasteboard) -> String? {
        // Preferred: file URLs (public.file-url / public.folder resolve to these).
        if let urls = pboard.readObjects(forClasses: [NSURL.self],
                                         options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            for url in urls where Self.isDirectory(url) {
                return url.path
            }
        }
        // Legacy: NSFilenamesPboardType carries an array of path strings.
        if let paths = pboard.propertyList(forType: .init("NSFilenamesPboardType")) as? [String] {
            for path in paths where Self.isDirectory(URL(fileURLWithPath: path)) {
                return path
            }
        }
        return nil
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }
}

/// Registers the Services provider once the app finishes launching. Bridged into
/// SwiftUI via `@NSApplicationDelegateAdaptor` in `StorageOptimizerApp`.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Retained for the app's lifetime — `NSApp.servicesProvider` holds it weakly.
    private let serviceProvider = FinderServiceProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = serviceProvider
        // Refresh the Services menu so our entry is available immediately rather
        // than only after the next registration cycle.
        NSUpdateDynamicServices()
    }
}
