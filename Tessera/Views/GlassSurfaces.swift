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
/// full-size content view + hidden title bar for a seamless top edge, but the
/// window is fully opaque — nothing from the desktop shows through, so the app
/// looks the same no matter what sits behind it.
///
/// (Name kept for existing call sites; it no longer makes the window transparent.)
struct TransparentWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { WindowReachingView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class WindowReachingView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.isOpaque = true
            window.backgroundColor = NSColor(Theme.bg)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            // Drag the window only from the (hidden) title-bar strip, never from
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
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(Theme.card, in: shape)
            .liquidGlassDepth(shape, shadowRadius: shadowRadius, shadowY: shadowY)
    }
}
