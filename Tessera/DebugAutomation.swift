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

        // Single-threaded scan benchmark:
        //   SO_BENCH=<path>           measure single-threaded scanSerial of <path>
        //   SO_BENCH_REPEATS=<n>      timed runs after a warm-up (default 3)
        //   SO_BENCH_PARALLEL=1       also time the parallel scan for comparison
        //   SO_AUTOQUIT=1             terminate when done
        if let benchPath = env["SO_BENCH"] {
            runBench(path: benchPath,
                     repeats: Int(env["SO_BENCH_REPEATS"] ?? "") ?? 3,
                     alsoParallel: env["SO_BENCH_PARALLEL"] == "1",
                     autoQuit: env["SO_AUTOQUIT"] == "1")
            return
        }

        // Incremental re-scan benchmark: full parallel scan, then a re-scan reusing
        // the prior tree (unchanged subtrees skipped).
        //   SO_BENCH_RESCAN=<path>   SO_AUTOQUIT=1
        if let benchPath = env["SO_BENCH_RESCAN"] {
            runRescanBench(path: benchPath, autoQuit: env["SO_AUTOQUIT"] == "1")
            return
        }

        guard let scanPath = env["SO_AUTOSCAN"] else { return }
        let snapshotDir = env["SO_SNAPSHOT_DIR"]
        let autoQuit = env["SO_AUTOQUIT"] == "1"

        log("automation armed: scan=\(scanPath)")
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            log("starting scan; windows=\(NSApp.windows.map { "\($0.title):num=\($0.windowNumber):visible=\($0.isVisible):opaque=\($0.isOpaque):bgAlpha=\(String(format: "%.2f", $0.backgroundColor.alphaComponent)):fullSizeContent=\($0.styleMask.contains(.fullSizeContentView))" })")
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
            // Cleanup classification is published async after the tree is built;
            // poll up to ~6s for it to land.
            var waited = 0
            while vm.cleanupReport == nil && waited < 6000 {
                try? await Task.sleep(for: .milliseconds(200)); waited += 200
            }
            if let report = vm.cleanupReport {
                log("cleanup: safe=\(Theme.format(report.safeTotalBytes)) in \(report.safeGroups.count) groups, \(report.reviewGroups.count) review groups")
                for g in report.groups {
                    log("  [\(g.category.confidence == .safeRegenerable ? "safe" : "review")] \(g.category.title): \(Theme.format(g.totalBytes)) (\(g.nodes.count))")
                }
            } else {
                log("cleanup: no report")
            }

            // Smart (on-device LLM) suggestions run async after the rule report.
            log("smart: available=\(SmartCleanupClassifier.isAvailable)")
            var swaited = 0
            while (vm.isClassifyingSmart || vm.smartSuggestions.isEmpty) && swaited < 40000 {
                try? await Task.sleep(for: .milliseconds(500)); swaited += 500
                if !vm.isClassifyingSmart && !vm.smartSuggestions.isEmpty { break }
                if !vm.isClassifyingSmart && swaited > 2000 { break }
            }
            for s in vm.smartSuggestions.prefix(12) {
                log("  smart[\(s.confidence)%] \(s.category): \(s.node.name) (\(Theme.format(s.node.size)))")
            }
            log("collector after auto-stage: \(vm.collector.count) items, \(Theme.format(vm.collectorTotalSize))")

            // Duplicate-finder benchmark (SO_DUPE_BENCH=1).
            if env["SO_DUPE_BENCH"] == "1", let root = vm.rootNode {
                let t0 = DispatchTime.now()
                let groups = await withCheckedContinuation { (cont: CheckedContinuation<[DuplicateGroup], Never>) in
                    DispatchQueue.global(qos: .userInitiated).async {
                        cont.resume(returning: DuplicateFinder.find(root: root) { _ in })
                    }
                }
                let dt = Double(DispatchTime.now().uptimeNanoseconds &- t0.uptimeNanoseconds) / 1e9
                let reclaim = groups.reduce(Int64(0)) { $0 + $1.reclaimableBytes }
                log(String(format: "DUPES: %.2fs — %d sets, %@ reclaimable", dt, groups.count, Theme.format(reclaim)))
            }

            // Let the wedge sweep-in animation settle
            try? await Task.sleep(for: .milliseconds(1200))
            if let dir = snapshotDir {
                snapshotKeyWindow(to: dir + "/complete.png")
                renderSunburst(root: vm.currentRoot, to: dir + "/sunburst.png")
                dumpLayout(root: vm.currentRoot, to: dir + "/layout.csv")
            }
            if autoQuit {
                NSApp.terminate(nil)
            } else {
                prepareForCapture()
            }
        }
    }

    /// Single-threaded scan benchmark. Warms the metadata cache once, then times
    /// `FileScanner.scanSerial` so the number reflects per-entry CPU cost (the
    /// thing we optimize) rather than cold-disk latency. Reports entries/sec and
    /// projects a 1 TB disk (~5.78M entries, from ~5,650 entries/GB measured on a
    /// real full-disk scan).
    private static func runBench(path: String, repeats: Int, alsoParallel: Bool, autoQuit: Bool) {
        Task.detached(priority: .userInitiated) {
            let url = URL(fileURLWithPath: path)
            log("BENCH single-threaded scanSerial of \(path)")

            // Warm-up pass: prime the kernel's metadata cache so timed runs are
            // CPU-bound, isolating the per-entry cost from one-time cold I/O.
            let warm = FileScanner.scanSerial(url: url)
            log("BENCH warm-up: dirs=\(warm.stats.dirs) files=\(warm.stats.files)")

            var best = Double.greatestFiniteMagnitude
            var stats = warm.stats
            for i in 0 ..< max(1, repeats) {
                let t0 = DispatchTime.now()
                let r = FileScanner.scanSerial(url: url)
                let dt = Double(DispatchTime.now().uptimeNanoseconds &- t0.uptimeNanoseconds) / 1e9
                stats = r.stats
                best = min(best, dt)
                let entries = Double(r.stats.dirs + r.stats.files)
                log(String(format: "BENCH serial run %d: %.3fs  %.0f entries/s  (%d dirs, %d files, %@)",
                           i + 1, dt, entries / dt, r.stats.dirs, r.stats.files, Theme.format(r.stats.bytes)))
                log(String(format: "         breakdown: enumerate %.2fs  build %.2fs  recompute %.2fs",
                           Double(r.stats.enumerateNanos) / 1e9,
                           Double(r.stats.buildNanos) / 1e9,
                           Double(r.stats.recomputeNanos) / 1e9))
                log(String(format: "         syscalls:  open %.2fs  getattrlistbulk %.2fs  close %.2fs",
                           Double(r.stats.openNanos) / 1e9,
                           Double(r.stats.bulkNanos) / 1e9,
                           Double(r.stats.closeNanos) / 1e9))
                let wall = Double(r.stats.enumerateNanos) / 1e9
                let cpu = Double(r.stats.cpuNanos) / 1e9
                log(String(format: "         thread CPU %.2fs of %.2fs wall → %.0f%% on-CPU (rest = I/O-blocked)",
                           cpu, wall, wall > 0 ? cpu / wall * 100 : 0))
            }

            let entries = Double(stats.dirs + stats.files)
            let eps = entries / best
            let entriesFor1TB = 5_780_000.0
            log(String(format: "BENCH serial BEST: %.3fs  %.0f entries/s  →  1 TB (~5.78M entries) projects to %.1fs single-threaded",
                       best, eps, entriesFor1TB / eps))

            if alsoParallel {
                // Warm-up parallel pass first (re-primes the cache the serial runs
                // may have churned), then a timed pass — so parallel is measured
                // under the same warm conditions as the serial best.
                _ = try? await FileScanner.scan(url: url) { _ in }
                var pbest = Double.greatestFiniteMagnitude
                for _ in 0 ..< 2 {
                    let t0 = DispatchTime.now()
                    let root = try? await FileScanner.scan(url: url) { _ in }
                    let dt = Double(DispatchTime.now().uptimeNanoseconds &- t0.uptimeNanoseconds) / 1e9
                    pbest = min(pbest, dt)
                    _ = root
                }
                let entries = Double(stats.dirs + stats.files)
                let speedup = pbest > 0 ? best / pbest : 0
                log(String(format: "BENCH parallel BEST: %.3fs  %.0f entries/s  (%.1fx vs single-thread)  →  1 TB projects to %.1fs",
                           pbest, entries / pbest, speedup, 5_780_000.0 / (entries / pbest)))
            }

            if autoQuit { await MainActor.run { NSApp.terminate(nil) } }
        }
    }

    /// Incremental re-scan benchmark: warm, full scan, then a re-scan that reuses
    /// the prior tree for unchanged subtrees. Reports both times + a correctness
    /// check that the incremental total matches the full total.
    private static func runRescanBench(path: String, autoQuit: Bool) {
        Task.detached(priority: .userInitiated) {
            let url = URL(fileURLWithPath: path)
            log("RESCAN bench: \(path)")
            _ = try? await FileScanner.scan(url: url) { _ in }   // warm caches

            let t1 = DispatchTime.now()
            let r1 = try? await FileScanner.scan(url: url) { _ in }
            let dt1 = Double(DispatchTime.now().uptimeNanoseconds &- t1.uptimeNanoseconds) / 1e9

            let t2 = DispatchTime.now()
            let r2 = try? await FileScanner.scan(url: url, cache: r1) { _ in }
            let dt2 = Double(DispatchTime.now().uptimeNanoseconds &- t2.uptimeNanoseconds) / 1e9

            let speedup = dt2 > 0 ? dt1 / dt2 : 0
            log(String(format: "RESCAN full=%.3fs  incremental=%.3fs  →  %.1fx faster", dt1, dt2, speedup))
            log("RESCAN correctness: full=\(r1?.size ?? -1)  incremental=\(r2?.size ?? -1)  " +
                "\(r1?.size == r2?.size ? "MATCH ✓" : "MISMATCH ✗")")

            if autoQuit { await MainActor.run { NSApp.terminate(nil) } }
        }
    }

    /// Interactive-capture mode (no SO_AUTOQUIT): size/centre the window, bring
    /// it frontmost and activate the app (which switches the active Space to it),
    /// then log its CGWindowID so an external `screencapture -l <id>` can grab the
    /// REAL behind-window glass that in-app `cacheDisplay` snapshots can't show.
    private static func prepareForCapture() {
        guard let window = NSApp.windows.first(where: { $0.isVisible }) ?? NSApp.windows.first else {
            log("CAPTURE: no window"); return
        }
        if let screen = window.screen ?? NSScreen.main {
            let target = NSSize(width: 1280, height: 840)
            let vf = screen.visibleFrame
            let origin = NSPoint(x: vf.midX - target.width / 2, y: vf.midY - target.height / 2)
            window.setFrame(NSRect(origin: origin, size: target), display: true)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        log("CAPTURE READY windowNumber=\(window.windowNumber) frame=\(NSStringFromRect(window.frame))")
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
            onZoomOut: {}, onAddToCollector: { _ in }, onRevealInFinder: { _ in },
            drag: CollectorDragController(), onDrop: { _ in }
        )
        .frame(width: 900, height: 900)
        // Offscreen renders have no desktop behind them; a neutral grey stands in
        // for the wallpaper so the pastel wedges are visible in the snapshot.
        .background(
            LinearGradient(colors: [Color(white: 0.30), Color(white: 0.16)],
                           startPoint: .top, endPoint: .bottom)
        )

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

    nonisolated private static func log(_ message: String) {
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
