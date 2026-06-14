import SwiftUI
import AppKit

// MARK: - Transparent window

/// Reaches the hosting `NSWindow` and turns it into a transparent glass pane:
/// the window itself paints nothing, so each panel (backed by a behind-window
/// `NSVisualEffectView`) refracts the desktop and the apps sitting behind the
/// app. Drop this into a `.background(...)` once, near the root of the view tree.
///
/// SwiftUI's `.glassEffect` only refracts *in-app* content — it cannot see past
/// the window onto the desktop — so true "glass pane over your desktop" requires
/// (a) a non-opaque window and (b) behind-window vibrancy on the panels.
struct TransparentWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { WindowReachingView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class WindowReachingView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
            window.isMovableByWindowBackground = true
            // Strip any opaque backing the hosting controller installed so the
            // desktop shows through the gutters between panels.
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
}

// MARK: - Behind-window desktop glass

/// A vibrancy surface clipped to a continuous rounded rectangle.
///
/// - `.behindWindow` blending blurs and refracts whatever sits behind the
///   (transparent) window — desktop wallpaper, other apps. Used for the faint
///   full-window base layer that gives the app visible bounds.
/// - `.withinWindow` blending blurs only the in-app content behind the view —
///   i.e. the base layer — so panels read as a gentle second sheet of glass
///   rather than each independently re-blurring the desktop (which stacked into
///   an overly strong frost).
struct DesktopGlass: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var emphasized: Bool = false
    var cornerRadius: CGFloat = 24

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        configure(view)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        configure(view)
    }

    private func configure(_ view: NSVisualEffectView) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = emphasized
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
    }
}

// MARK: - Panel modifier

extension View {
    /// Backs a panel with a single sheet of glass clipped to a rounded rect, then
    /// layers the Liquid Glass highlight lip + ambient shadow on top. One glass
    /// surface under sharp content — never glass-on-glass — so labels and controls
    /// stay crisp instead of double-blurring into a frosted smear.
    ///
    /// Uses `.withinWindow` blending so the panel frosts the faint window-base
    /// glass beneath it instead of re-sampling the desktop a second time; this is
    /// what keeps the stacked-card effect gentle rather than heavy.
    func desktopGlassPanel(cornerRadius: CGFloat = 24,
                           material: NSVisualEffectView.Material = .hudWindow,
                           shadowRadius: CGFloat = 28,
                           shadowY: CGFloat = 16) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(
                DesktopGlass(material: material, blendingMode: .withinWindow,
                             emphasized: false, cornerRadius: cornerRadius)
            )
            .liquidGlassDepth(shape, shadowRadius: shadowRadius, shadowY: shadowY)
    }
}
