import SwiftUI
import AppKit

@MainActor
final class ScanViewModel: ObservableObject {
    // MARK: - Published state
    @Published var rootNode: FileNode?
    @Published var currentRoot: FileNode?        // zoom target within the chart
    @Published var hoveredNode: FileNode?
    @Published var selectedNode: FileNode?
    @Published var collector: [FileNode] = []
    @Published var isScanning = false
    @Published var progress = ScanProgress()
    @Published var errorMessage: String?
    @Published var needsFullDiskAccess = false

    private var scanTask: Task<Void, Never>?
    /// Diagnostic: true when the last scan ended via CancellationError.
    private(set) var scanTaskWasCancelled = false

    // MARK: - Computed

    var collectorTotalSize: Int64 { collector.reduce(0) { $0 + $1.size } }

    // MARK: - Scan

    func startScan(volumeURL: URL) {
        scanTask?.cancel()
        rootNode = nil
        scanTaskWasCancelled = false
        currentRoot = nil
        hoveredNode = nil
        selectedNode = nil
        collector = []
        errorMessage = nil
        needsFullDiskAccess = false
        isScanning = true
        progress = ScanProgress(currentPath: volumeURL.path)

        scanTask = Task {
            do {
                let node = try await FileScanner.scan(url: volumeURL) { [weak self] prog in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        // Monotonicity guard: discard stale ticks that arrive out of order.
                        if prog.dirsScanned >= self.progress.dirsScanned
                            || prog.dirsDiscovered > self.progress.dirsDiscovered {
                            self.progress = prog
                        }
                    }
                }
                let treeIsEmpty = node.children.isEmpty
                let volumePath = volumeURL.path
                let isVolumeRoot = volumePath == "/"
                let isUnreadable = !FileManager.default.isReadableFile(atPath: volumePath)
                if treeIsEmpty && (isVolumeRoot || isUnreadable) {
                    self.needsFullDiskAccess = true
                }
                self.rootNode = node
                self.currentRoot = node
            } catch is CancellationError {
                // User stopped the scan — not an error.
                self.scanTaskWasCancelled = true
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isScanning = false
        }
    }

    func cancelScan() {
        scanTask?.cancel()
    }

    // MARK: - Chart navigation

    func zoomIn(to node: FileNode) {
        guard node.isDirectory else { return }
        currentRoot = node
        hoveredNode = nil
        selectedNode = node
    }

    func zoomOut() {
        guard let current = currentRoot, let parent = current.parent else { return }
        currentRoot = parent
        selectedNode = parent
        hoveredNode = nil
    }

    func zoomToRoot() {
        currentRoot = rootNode
        selectedNode = rootNode
        hoveredNode = nil
    }

    // MARK: - Collector

    func addToCollector(_ node: FileNode) {
        guard !node.isSynthetic else { return }
        guard !collector.contains(where: { $0.id == node.id }) else { return }

        // Refuse if any existing collector item is an ancestor of this node.
        func isAncestor(_ candidate: FileNode, of target: FileNode) -> Bool {
            var cursor = target.parent
            while let p = cursor {
                if p.id == candidate.id { return true }
                cursor = p.parent
            }
            return false
        }
        guard !collector.contains(where: { isAncestor($0, of: node) }) else { return }

        // Remove any existing collector items that are descendants of the new node
        // (collecting a parent supersedes its children).
        collector.removeAll { isAncestor(node, of: $0) }

        collector.append(node)
    }

    func removeFromCollector(_ node: FileNode) {
        collector.removeAll { $0.id == node.id }
    }

    func clearCollector() {
        collector = []
    }

    // MARK: - Delete

    func deleteCollector() throws {
        let urls = collector.map(\.url)
        let failures = try TrashService.trash(urls)

        // Remove successfully trashed nodes from the tree
        let failedURLs = Set(failures.map(\.url))
        for node in collector where !failedURLs.contains(node.url) {
            node.parent?.remove(node)
        }
        collector.removeAll { !failedURLs.contains($0.url) }

        // Always clear hover/selection after a delete.
        hoveredNode = nil
        selectedNode = nil

        // Ensure currentRoot is still reachable from rootNode.
        // Walk its parent chain; if it doesn't terminate at rootNode, walk upward
        // through .parent until we find a node whose chain does, or fall back to rootNode.
        func isReachable(_ node: FileNode, from root: FileNode) -> Bool {
            var cursor: FileNode? = node
            while let c = cursor {
                if c.id == root.id { return true }
                cursor = c.parent
            }
            return false
        }

        var correctedRoot = currentRoot
        if let root = rootNode, let candidate = correctedRoot {
            if !isReachable(candidate, from: root) {
                // Walk up from candidate until we find a reachable ancestor.
                var cursor: FileNode? = candidate.parent
                var found: FileNode? = nil
                while let c = cursor {
                    if isReachable(c, from: root) {
                        found = c
                        break
                    }
                    cursor = c.parent
                }
                correctedRoot = found ?? root
            }
        }

        // Force chart redraw with the corrected (and safe) root.
        currentRoot = nil
        currentRoot = correctedRoot

        if let firstFailure = failures.first {
            throw firstFailure
        }
    }

    // MARK: - Full Disk Access

    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
