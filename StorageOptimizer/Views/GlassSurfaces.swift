import SwiftUI
import AppKit

// MARK: - Glass tuning

/// Central tuning for the app's frosted-glass look. The constants below are the
/// shipping design values. In DEBUG builds each value can be overridden from the
/// environment (SO_BASE_MATERIAL / SO_BASE_EMPHASIZED / SO_BASE_TINT /
/// SO_CARD_MATERIAL) so the materials can be A/B compared live without
/// rebuilding; release builds use the constants only.
enum GlassTuning {
    /// Window base: a strong behind-window frost that blurs the desktop while
    /// still letting its colour read through — a clear frosted-glass pane, not a
    /// near-transparent hole and not a flat opaque panel.
    static var baseMaterial: NSVisualEffectView.Material {
        #if DEBUG
        if let m = appKitMaterial(ProcessInfo.processInfo.environment["SO_BASE_MATERIAL"]) { return m }
        #endif
        return .fullScreenUI
    }
    static var baseEmphasized: Bool {
        #if DEBUG
        if let v = ProcessInfo.processInfo.environment["SO_BASE_EMPHASIZED"] { return v == "1" }
        #endif
        return false
    }
    /// A gentle dark wash over the base to deepen the frost and keep the data
    /// legible over busy wallpaper, without flattening the blur.
    static var baseTint: Double {
        #if DEBUG
        if let v = ProcessInfo.processInfo.environment["SO_BASE_TINT"], let d = Double(v) { return d }
        #endif
        return 0.12
    }

    /// Panels/cards: a within-window material light enough to only just frost the
    /// base beneath them (a hint of what's behind shows through) while staying
    /// opaque enough to read as distinct panels with crisp text.
    static var cardMaterial: Material {
        #if DEBUG
        if let m = swiftUIMaterial(ProcessInfo.processInfo.environment["SO_CARD_MATERIAL"]) { return m }
        #endif
        return .regularMaterial
    }

    private static func appKitMaterial(_ s: String?) -> NSVisualEffectView.Material? {
        switch s {
        case "hudWindow": return .hudWindow
        case "fullScreenUI": return .fullScreenUI
        case "underWindowBackground": return .underWindowBackground
        case "windowBackground": return .windowBackground
        case "popover": return .popover
        case "menu": return .menu
        case "sidebar": return .sidebar
        case "headerView": return .headerView
        default: return nil
        }
    }

    private static func swiftUIMaterial(_ s: String?) -> Material? {
        switch s {
        case "ultraThin": return .ultraThinMaterial
        case "thin": return .thinMaterial
        case "regular": return .regularMaterial
        case "thick": return .thickMaterial
        case "ultraThick": return .ultraThickMaterial
        default: return nil
        }
    }
}

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
    /// Backs a panel with a single LIGHT sheet of glass clipped to a rounded
    /// rect, then layers the Liquid Glass highlight lip + ambient shadow on top.
    /// One glass surface under sharp content — never glass-on-glass — so labels
    /// and controls stay crisp instead of double-blurring into a frosted smear.
    ///
    /// Uses a SwiftUI within-window `Material` rather than behind-window vibrancy:
    /// the panel lightly frosts the strongly-frosted window base beneath it — just
    /// enough to read as glass and let a hint of the base show through — instead
    /// of re-blurring the desktop into a heavy opaque card. This is what keeps the
    /// panels subtle while the window base carries the strong blur.
    func desktopGlassPanel(cornerRadius: CGFloat = 24,
                           shadowRadius: CGFloat = 28,
                           shadowY: CGFloat = 16) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .background(GlassTuning.cardMaterial, in: shape)
            .liquidGlassDepth(shape, shadowRadius: shadowRadius, shadowY: shadowY)
    }
}
