import Testing
import Foundation
@testable import StorageOptimizer

// MARK: - Fixture builder

/// Build a hand-wired 3-level tree:
///
///   root (dir, size=0)
///   ├── childA (dir, size=0)
///   │   ├── grandchildA1 (file, size=100)
///   │   └── grandchildA2 (file, size=200)
///   └── childB (file, size=50)
///
/// Sizes are set manually; call recomputeDirectorySizes() to roll them up.
private func makeTree() -> FileNode {
    let tmpURL = URL(fileURLWithPath: "/tmp/test-tree")

    let root = FileNode(url: tmpURL.appendingPathComponent("root"),
                        name: "root", isDirectory: true, size: 0)

    let childA = FileNode(url: tmpURL.appendingPathComponent("root/a"),
                          name: "a", isDirectory: true, size: 0)

    let gc1 = FileNode(url: tmpURL.appendingPathComponent("root/a/gc1"),
                       name: "gc1", isDirectory: false, size: 100)
    let gc2 = FileNode(url: tmpURL.appendingPathComponent("root/a/gc2"),
                       name: "gc2", isDirectory: false, size: 200)

    let childB = FileNode(url: tmpURL.appendingPathComponent("root/b"),
                          name: "b", isDirectory: false, size: 50)

    childA.setChildren([gc1, gc2])
    root.setChildren([childA, childB])
    root.recomputeDirectorySizes()
    return root
}

@Suite("ViewModel Tests")
@MainActor
struct ViewModelTests {

    // MARK: - Collector: add / remove / clear / no duplicates

    @Test("Collector add, remove, clear and total size are correct")
    func collectorAddRemoveClear() {
        let vm = ScanViewModel()
        let root = makeTree()
        guard let childA = root.children.first(where: { $0.name == "a" }),
              let childB = root.children.first(where: { $0.name == "b" }) else {
            Issue.record("Fixture tree missing expected children")
            return
        }

        // Initially empty
        #expect(vm.collector.isEmpty)
        #expect(vm.collectorTotalSize == 0)

        vm.addToCollector(childA)
        #expect(vm.collector.count == 1)
        #expect(vm.collectorTotalSize == childA.size)

        vm.addToCollector(childB)
        #expect(vm.collector.count == 2)
        #expect(vm.collectorTotalSize == childA.size + childB.size)

        vm.removeFromCollector(childA)
        #expect(vm.collector.count == 1)
        #expect(vm.collectorTotalSize == childB.size)

        vm.clearCollector()
        #expect(vm.collector.isEmpty)
        #expect(vm.collectorTotalSize == 0)
    }

    @Test("addToCollector does not add the same node twice")
    func collectorNoDuplicates() {
        let vm = ScanViewModel()
        let root = makeTree()
        guard let childB = root.children.first(where: { $0.name == "b" }) else {
            Issue.record("Missing childB")
            return
        }

        vm.addToCollector(childB)
        vm.addToCollector(childB)
        vm.addToCollector(childB)
        #expect(vm.collector.count == 1)
    }

    // MARK: - Collector: rejects synthetic nodes

    @Test("addToCollector refuses .hiddenSpace and .aggregate nodes")
    func collectorRefusesSynthetic() {
        let vm = ScanViewModel()
        let base = URL(fileURLWithPath: "/tmp")

        let hiddenNode = FileNode(url: base.appendingPathComponent("hidden"),
                                  name: "Hidden Space", isDirectory: false,
                                  size: 1024, kind: .hiddenSpace)
        let aggNode = FileNode(url: base.appendingPathComponent("other"),
                               name: "Other", isDirectory: false,
                               size: 512, kind: .aggregate)

        vm.addToCollector(hiddenNode)
        vm.addToCollector(aggNode)
        #expect(vm.collector.isEmpty,
                "Synthetic nodes should not be added to collector")
    }

    // MARK: - Zoom navigation

    @Test("zoomIn only works on directories; zoomOut walks to parent; zoomToRoot restores")
    func zoomNavigation() {
        let vm = ScanViewModel()
        let root = makeTree()
        guard let childA = root.children.first(where: { $0.name == "a" }),
              let childB = root.children.first(where: { $0.name == "b" }) else {
            Issue.record("Fixture tree missing expected children")
            return
        }

        vm.rootNode = root
        vm.currentRoot = root

        // zoomIn on a file should be a no-op
        vm.zoomIn(to: childB)
        #expect(vm.currentRoot?.id == root.id,
                "zoomIn on a file should not change currentRoot")

        // zoomIn on a directory
        vm.zoomIn(to: childA)
        #expect(vm.currentRoot?.id == childA.id)
        #expect(vm.selectedNode?.id == childA.id)
        #expect(vm.hoveredNode == nil)

        // zoomOut should go back to root
        vm.zoomOut()
        #expect(vm.currentRoot?.id == root.id)
        #expect(vm.selectedNode?.id == root.id)
        #expect(vm.hoveredNode == nil)

        // zoomIn again, then zoomToRoot
        vm.zoomIn(to: childA)
        vm.zoomToRoot()
        #expect(vm.currentRoot?.id == root.id)
        #expect(vm.selectedNode?.id == root.id)
    }

    @Test("zoomOut is a no-op when currentRoot has no parent")
    func zoomOutAtRoot() {
        let vm = ScanViewModel()
        let root = makeTree()
        vm.rootNode = root
        vm.currentRoot = root

        vm.zoomOut() // root has no parent
        #expect(vm.currentRoot?.id == root.id)
    }

    // MARK: - FileNode.remove propagates size decrease

    @Test("FileNode.remove propagates the size decrease to all ancestors")
    func removePropagatesSizeDecrease() {
        let root = makeTree()
        guard let childA = root.children.first(where: { $0.name == "a" }),
              let gc1 = childA.children.first(where: { $0.name == "gc1" }) else {
            Issue.record("Fixture tree missing expected nodes")
            return
        }

        let rootBefore = root.size    // 350
        let aBefore = childA.size     // 300
        let gc1Size = gc1.size        // 100

        childA.remove(gc1)

        #expect(childA.size == aBefore - gc1Size,
                "childA size should decrease by gc1.size")
        #expect(root.size == rootBefore - gc1Size,
                "root size should decrease by gc1.size")
        #expect(!childA.children.contains(where: { $0.id == gc1.id }),
                "gc1 should no longer be a child of childA")
    }

    // MARK: - FileNode.recomputeDirectorySizes on 3-level tree

    @Test("recomputeDirectorySizes correctly rolls up a 3-level tree from scratch")
    func recomputeDirectorySizes() {
        let tmpURL = URL(fileURLWithPath: "/tmp/recompute-test")

        let root = FileNode(url: tmpURL, name: "root", isDirectory: true, size: 999)

        let dir1 = FileNode(url: tmpURL.appendingPathComponent("dir1"),
                            name: "dir1", isDirectory: true, size: 999)
        let dir2 = FileNode(url: tmpURL.appendingPathComponent("dir2"),
                            name: "dir2", isDirectory: true, size: 999)

        let f1 = FileNode(url: tmpURL.appendingPathComponent("dir1/f1"),
                          name: "f1", isDirectory: false, size: 400)
        let f2 = FileNode(url: tmpURL.appendingPathComponent("dir1/f2"),
                          name: "f2", isDirectory: false, size: 600)
        let f3 = FileNode(url: tmpURL.appendingPathComponent("dir2/f3"),
                          name: "f3", isDirectory: false, size: 300)

        dir1.setChildren([f1, f2])
        dir2.setChildren([f3])
        root.setChildren([dir1, dir2])

        // Sizes start as garbage (999) for dirs — recompute should fix them
        root.recomputeDirectorySizes()

        #expect(dir1.size == 1000, "dir1 should sum f1+f2 = 1000")
        #expect(dir2.size == 300,  "dir2 should sum f3 = 300")
        #expect(root.size == 1300, "root should sum dir1+dir2 = 1300")
    }
}
