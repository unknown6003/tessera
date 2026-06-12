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
    @Published var progress = ScanProgress(filesScanned: 0, bytesFound: 0, totalBytes: 0, currentPath: "")
    @Published var errorMessage: String?
    @Published var needsFullDiskAccess = false

    private var scanTask: Task<Void, Never>?

    // MARK: - Computed

    var collectorTotalSize: Int64 { collector.reduce(0) { $0 + $1.size } }

    // MARK: - Scan

    func startScan(volumeURL: URL) {
        scanTask?.cancel()
        rootNode = nil
        currentRoot = nil
        hoveredNode = nil
        selectedNode = nil
        collector = []
        errorMessage = nil
        needsFullDiskAccess = false
        isScanning = true
        progress = ScanProgress(filesScanned: 0, bytesFound: 0, totalBytes: 0, currentPath: volumeURL.path)

        scanTask = Task {
            do {
                let node = try await FileScanner.scan(url: volumeURL) { [weak self] prog in
                    Task { @MainActor [weak self] in
                        self?.progress = prog
                    }
                }
                if node.size == 0 && node.children.isEmpty {
                    self.needsFullDiskAccess = true
                }
                self.rootNode = node
                self.currentRoot = node
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isScanning = false
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        isScanning = false
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
        guard !collector.contains(where: { $0.id == node.id }) else { return }
        // Don't add ancestors/descendants of things already in the list
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

        // Force chart redraw
        let saved = currentRoot
        currentRoot = nil
        currentRoot = saved

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
