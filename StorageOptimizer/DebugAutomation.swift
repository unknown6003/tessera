import SwiftUI
import AppKit

/// Headless E2E driver, active only when launched with environment variables:
///   SO_AUTOSCAN=<path>       start scanning <path> on launch
///   SO_SNAPSHOT_DIR=<dir>    write window snapshots (scanning.png, complete.png) to <dir>
///   SO_AUTOQUIT=1            terminate after the final snapshot
/// Inert in normal launches.
@MainActor
enum DebugAutomation {
    static func runIfRequested(vm: ScanViewModel) {
        let env = ProcessInfo.processInfo.environment
        guard let scanPath = env["SO_AUTOSCAN"] else { return }
        let snapshotDir = env["SO_SNAPSHOT_DIR"]
        let autoQuit = env["SO_AUTOQUIT"] == "1"

        log("automation armed: scan=\(scanPath)")
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            log("starting scan; windows=\(NSApp.windows.map { "\($0.title):visible=\($0.isVisible)" })")
            let scanStart = Date()
            vm.startScan(volumeURL: URL(fileURLWithPath: scanPath))

            try? await Task.sleep(for: .milliseconds(700))
            if let dir = snapshotDir, vm.isScanning {
                snapshotKeyWindow(to: dir + "/scanning.png")
            }

            var ticks = 0
            while vm.isScanning {
                try? await Task.sleep(for: .milliseconds(200))
                ticks += 1
                if ticks % 150 == 0 {  // every ~30s
                    let p = vm.progress
                    log("progress: dirs \(p.dirsScanned)/\(p.dirsDiscovered) files \(p.filesScanned) at \(p.currentPath)")
                }
            }
            let p = vm.progress
            let elapsed = Date().timeIntervalSince(scanStart)
            let rate = elapsed > 0 ? Int(Double(p.dirsScanned) / elapsed) : 0
            log("scan finished: root=\(vm.rootNode?.size ?? -1) error=\(vm.errorMessage ?? "none") " +
                "cancelled=\(vm.scanTaskWasCancelled) dirs \(p.dirsScanned)/\(p.dirsDiscovered) " +
                "elapsed=\(String(format: "%.2f", elapsed))s rate=\(rate) dirs/s")
            // Let the wedge sweep-in animation settle
            try? await Task.sleep(for: .milliseconds(1200))
            if let dir = snapshotDir {
                snapshotKeyWindow(to: dir + "/complete.png")
                renderSunburst(root: vm.currentRoot, to: dir + "/sunburst.png")
                dumpLayout(root: vm.currentRoot, to: dir + "/layout.csv")
            }
            if autoQuit {
                NSApp.terminate(nil)
            }
        }
    }

    private static func snapshotKeyWindow(to path: String) {
        guard let window = NSApp.windows.first(where: { $0.isVisible }) ?? NSApp.windows.first else {
            log("snapshot \(path): no window"); return
        }
        guard let view = window.contentView else { log("snapshot \(path): no contentView"); return }
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            log("snapshot \(path): no bitmap rep (bounds=\(view.bounds))"); return
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            log("snapshot \(path): png encode failed"); return
        }
        do { try data.write(to: URL(fileURLWithPath: path)); log("snapshot written: \(path)") }
        catch { log("snapshot \(path): write failed \(error)") }
    }

    /// Rasterize the sunburst alone (no glass/window compositing) so the chart
    /// rendering can be verified even where window capture is unavailable.
    private static func renderSunburst(root: FileNode?, to path: String) {
        let chart = SunburstChart(
            root: root, hoveredNode: nil, selectedNode: nil,
            onHover: { _ in }, onSelect: { _ in }, onZoomIn: { _ in },
            onZoomOut: {}, onAddToCollector: { _ in }, onRevealInFinder: { _ in }
        )
        .frame(width: 900, height: 900)
        .background(Rectangle().fill(Theme.backgroundGradient))

        let renderer = ImageRenderer(content: chart)
        renderer.scale = 2
        guard let cgImage = renderer.cgImage else { log("sunburst render: nil image"); return }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
        log("sunburst rendered: \(path)")
    }

    private static func dumpLayout(root: FileNode?, to path: String) {
        guard let root else { return }
        let wedges = SunburstChart.buildLayout(root: root)
        var csv = "depth,start,end,size,name\n"
        for w in wedges {
            csv += "\(w.depth),\(w.startAngle),\(w.endAngle),\(w.node.size),\"\(w.node.name)\"\n"
        }
        try? csv.write(toFile: path, atomically: true, encoding: .utf8)
        log("layout dumped: \(path) (\(wedges.count) wedges)")
    }

    private static func log(_ message: String) {
        let line = "[DebugAutomation] \(message)\n"
        FileHandle.standardError.write(Data(line.utf8))
        if let dir = ProcessInfo.processInfo.environment["SO_SNAPSHOT_DIR"],
           let data = line.data(using: .utf8) {
            let url = URL(fileURLWithPath: dir + "/automation.log")
            if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(data); try? h.close() }
            else { try? data.write(to: url) }
        }
    }
}
