import SwiftUI
import AppKit

struct SunburstRepresentable: NSViewRepresentable {
    let root: FileNode?
    let highlightedNode: FileNode?
    var onHover: NodeCallback
    var onSelect: NodeCallback
    var onZoom: NodeCallback

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> SunburstNSView {
        let view = SunburstNSView()
        view.onHover   = onHover
        view.onSelect  = onSelect
        view.onZoom    = onZoom
        return view
    }

    func updateNSView(_ nsView: SunburstNSView, context: Context) {
        // Only recompute layout when the root changes (expensive tree walk)
        if nsView.root?.id != root?.id {
            nsView.root = root
        }
        nsView.highlightedNode = highlightedNode
        // Keep callbacks in sync (captures may change)
        nsView.onHover  = onHover
        nsView.onSelect = onSelect
        nsView.onZoom   = onZoom
    }
}
