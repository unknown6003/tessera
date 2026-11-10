import SwiftUI
import AppKit

// Flat design system surfaces.
//
// This file used to host the app's "Liquid Glass" layer: NSVisualEffectView
// vibrancy (`DesktopGlass`), a non-opaque window that refracted the desktop, and
// material/tint tuning (`GlassTuning`). All of it is gone — the app now paints
// solid surfaces with hairline borders, matching the landing site's flat,
// single-accent system (see DESIGN.md). What remains is an opaque window and one
// solid panel modifier.

// MARK: - Opaque window

/// Reaches the hosting `NSWindow` and paints it a solid near-black. Keeps the
/// native toolbar for a continuous top edge. The window is opaque, so the
/// desktop does not change the content behind the map.
///
/// (Name kept for existing call sites; it no longer makes the window transparent.)
struct TransparentWindowConfigurator: NSViewRepresentable {
    /// Reports the window this view lives in, from `viewDidMoveToWindow`.
    /// Callers use it to compare identity with `NSApp.keyWindow`.
    var onWindow: (NSWindow) -> Void = { _ in }

    func makeNSView(context: Context) -> NSView { WindowReachingView(onWindow: onWindow) }
    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? WindowReachingView)?.onWindow = onWindow
    }

    private final class WindowReachingView: NSView {
        var onWindow: (NSWindow) -> Void

        init(onWindow: @escaping (NSWindow) -> Void) {
            self.onWindow = onWindow
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            onWindow(window)
            window.isOpaque = true
            window.backgroundColor = NSColor(Theme.bg)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            // Drag the window only from the native title bar, never from
            // the content body — background-movability fought the chart's wedge
            // drag-and-drop.
            window.isMovableByWindowBackground = false
            window.isMovable = true
            window.appearance = NSAppearance(named: .darkAqua)
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.backgroundColor = NSColor(Theme.bg).cgColor
        }
    }
}

// MARK: - Panel modifier

extension View {
    /// Backs a panel with a solid card fill clipped to a rounded rect, plus a
    /// hairline border and a soft neutral shadow (via `liquidGlassDepth`). No
    /// vibrancy and no glass-on-glass — crisp text on a solid surface.
    func desktopGlassPanel(cornerRadius: CGFloat = 24,
                           shadowRadius: CGFloat = 28,
                           shadowY: CGFloat = 16) -> some View {
        // Keep the old call sites source-compatible while enforcing the quieter
        // content geometry used by the redesigned shell.
        let shape = RoundedRectangle(cornerRadius: min(cornerRadius, 16), style: .continuous)
        return self
            .background(Theme.card, in: shape)
            .liquidGlassDepth(shape, shadowRadius: min(shadowRadius, 12), shadowY: min(shadowY, 6))
    }
}
