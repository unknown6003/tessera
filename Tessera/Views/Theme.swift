import SwiftUI
import AppKit

// MARK: - Hex color helper

extension Color {
    /// Build an opaque sRGB color from a 0xRRGGBB literal.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

enum Theme {
    static func itemCount(_ count: Int) -> String {
        "\(count.formatted()) \(count == 1 ? "item" : "items")"
    }

    // MARK: - Flat design tokens
    //
    // One flat, single-accent dark system shared with the landing site (see
    // DESIGN.md). Solid fills + hairline borders only — no gradients, glows, or
    // frosted materials. 60/30/10 by area: near-black void, neutral structure,
    // one electric-cyan accent.

    /// 60% — the dominant near-black void (page + largest surfaces).
    static let bg = Color(hex: 0x0A0B0D)
    /// Secondary surface: pills, insets, secondary fills.
    static let surface = Color(hex: 0x101216)
    /// Panels / cards.
    static let card = Color(hex: 0x131418)
    /// Raised panels / popovers.
    static let elevated = Color(hex: 0x17191E)
    /// Primary text.
    static let foreground = Color(hex: 0xF3F4F6)
    /// Secondary text.
    static let mutedForeground = Color(hex: 0x969BA4)
    /// Default 1px hairline border.
    static let border = Color.white.opacity(0.08)
    /// Emphasis hairline border.
    static let borderStrong = Color.white.opacity(0.14)

    // MARK: - Accent

    /// The single accent: electric cyan (#1BE6FF). Drives the global tint,
    /// selection, progress, and the anchor of the chart palette. (Matches the
    /// site's `--brand`.)
    static let electricBlue = Color(hex: 0x1BE6FF)
    /// Text/icons drawn on top of an accent fill.
    static let brandInk = Color(hex: 0x04171C)
    /// Destructive / irreversible actions only.
    static let danger = Color(hex: 0xFF5C7A)

    /// Hue of `electricBlue` in the 0…1 wheel (~186.6°) — the centre of the
    /// wedge palette band.
    static let electricBlueHue: Double = 186.6 / 360.0

    /// Solid window background (kept named `windowTint` for existing call sites).
    static let windowTint = bg

    // MARK: - Chart palette (flat, solid)

    /// Categorical chart palette for the top ring — the site's sunburst family
    /// (cyan · teal · blue · violet · green · pink · amber), interleaved so
    /// neighbours separate. Each top-level branch keeps its hue at every depth.
    private static let sunburstHex: [UInt32] = [
        0x1BE6FF, 0x37E0C8, 0x5B8CFF, 0x9E6BFF, 0x5BE36B, 0xFF5CC8, 0xFFB13C,
    ]
    static let sunburstColors: [Color] = sunburstHex.map { Color(hex: $0) }
    /// Number of distinct branch hues. Top-level ranks at or past this count
    /// draw in the neutral grey; the palette never repeats.
    static let branchPaletteCount = sunburstHex.count

    /// Fixed share of `bg` mixed into each ring, by depth. Opaque sRGB mixes, not
    /// opacity, so hover washes and hairline gaps stay clean and child rings
    /// read as a deeper step of the same branch.
    private static let depthMix: [Double] = [0, 0.12, 0.22, 0.30, 0.36]
    /// Increase Contrast keeps every ring at 3:1 or more on `bg`. Measured:
    /// the weakest default step (violet, depth 4) is 2.90:1; at 0.20 it is
    /// above 3.5:1.
    private static let depthMixHighContrast: [Double] = [0, 0.06, 0.12, 0.16, 0.20]

    /// Precomputed [palette][depth] tables. Drawing reads them per wedge; no
    /// colour math runs per frame.
    private static let wedgeShades: [[Color]] = sunburstHex.map { hex in
        depthMix.map { mix(hex, toward: 0x0A0B0D, amount: $0) }
    }
    private static let wedgeShadesHighContrast: [[Color]] = sunburstHex.map { hex in
        depthMixHighContrast.map { mix(hex, toward: 0x0A0B0D, amount: $0) }
    }

    /// Solid wedge colour for a top-level branch `palette` at ring `depth`.
    /// `nil` palette marks a wedge too small to tell apart; it uses the
    /// aggregate neutral, like DaisyDisk's grey "small items". An index
    /// outside the palette is also neutral: hues never wrap and repeat.
    static func wedgeColor(palette: Int?, depth: Int, highContrast: Bool = false) -> Color {
        let table = highContrast ? wedgeShadesHighContrast : wedgeShades
        guard let palette, table.indices.contains(palette) else {
            return highContrast ? aggregateColorHighContrast : aggregateColor
        }
        let row = table[palette]
        return row[min(max(0, depth), row.count - 1)]
    }

    /// Fixed colour for synthetic node kinds. `nil` for real files and folders.
    static func syntheticColor(for kind: FileNode.Kind, highContrast: Bool = false) -> Color? {
        switch kind {
        case .hiddenSpace:      return highContrast ? Color(hex: 0x6A707A) : hiddenSpaceColor
        case .aggregate:        return highContrast ? aggregateColorHighContrast : aggregateColor
        case .cloudOnlyStorage: return highContrast ? Color(hex: 0x3F7A8A) : cloudColor
        case .crossVolume:      return crossVolumeColor
        case .regular, .package: return nil
        }
    }

    /// 3.11:1 on `bg` (default aggregate is 1.86:1).
    static let aggregateColorHighContrast = Color(hex: 0x5A606A)

    private static func mix(_ hex: UInt32, toward other: UInt32, amount t: Double) -> Color {
        func channel(_ v: UInt32, _ shift: UInt32) -> Double { Double((v >> shift) & 0xFF) / 255.0 }
        func lerp(_ shift: UInt32) -> Double {
            channel(hex, shift) * (1 - t) + channel(other, shift) * t
        }
        return Color(.sRGB, red: lerp(16), green: lerp(8), blue: lerp(0), opacity: 1)
    }

    // MARK: - Synthetic node colours (solid)

    /// Solid neutral for "Hidden Space" (space the scan cannot see).
    static let hiddenSpaceColor = Color(hex: 0x454B54)
    /// Solid, darker neutral for aggregated "Other" slices.
    static let aggregateColor = Color(hex: 0x3A3F47)
    /// Desaturated cyan for online-only cloud nodes — same family, washed out.
    static let cloudColor = Color(hex: 0x2E5A66)
    /// Amber for cross-mounted volumes.
    static let crossVolumeColor = Color(hex: 0xFFB13C)

    // MARK: - Selection

    /// Selected-state fill: a low-opacity accent wash over a solid panel.
    static let selectionTint = electricBlue.opacity(0.16)

    // MARK: - Contrast

    /// A readable text/icon colour to draw on top of `background`: dark ink on
    /// light fills, light text on dark fills. Keeps labels legible across the
    /// whole categorical palette (bright cyan wedges *and* the dark neutrals used
    /// for hidden/aggregate/cloud nodes).
    static func ink(on background: Color) -> Color {
        guard let c = NSColor(background).usingColorSpace(.sRGB) else { return foreground }
        let l = 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
        return l > 0.55 ? brandInk : foreground
    }

    // MARK: - Formatting

    /// Human-readable size string, monospaced-digit friendly (e.g. "4.2 GB").
    static func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    // MARK: - Icons

    /// SF Symbol name for a node. Falls back to generic per kind.
    static func icon(for node: FileNode) -> String {
        switch node.kind {
        case .hiddenSpace: return "eye.slash.fill"
        case .aggregate:   return "ellipsis.circle.fill"
        case .cloudOnlyStorage: return "icloud.fill"
        case .crossVolume: return "externaldrive.fill"
        case .package:
            let ext = (node.name as NSString).pathExtension.lowercased()
            switch ext {
            case "app":       return "app.fill"
            case "framework", "dylib", "bundle": return "shippingbox.fill"
            case "plugin", "kext": return "puzzlepiece.extension.fill"
            default:          return "shippingbox.fill"
            }
        case .regular:
            if node.isDirectory { return "folder.fill" }
            let ext = (node.name as NSString).pathExtension.lowercased()
            return iconForExtension(ext)
        }
    }

    // MARK: - Private helpers

    private static func iconForExtension(_ ext: String) -> String {
        switch ext {
        // Video
        case "mp4", "mov", "m4v", "avi", "mkv", "wmv", "hevc", "webm":
            return "film.fill"
        // Audio
        case "mp3", "m4a", "aac", "flac", "wav", "aiff", "ogg":
            return "music.note"
        // Image
        case "jpg", "jpeg", "png", "gif", "heic", "tiff", "webp", "raw", "bmp", "svg":
            return "photo.fill"
        // Archive
        case "zip", "tar", "gz", "bz2", "xz", "7z", "rar", "dmg", "iso", "pkg":
            return "archivebox.fill"
        // Code / text
        case "swift", "m", "mm", "c", "cpp", "h", "hpp", "py", "js", "ts",
             "rb", "go", "rs", "java", "kt", "sh", "bash", "zsh":
            return "chevron.left.forwardslash.chevron.right"
        case "json", "yaml", "yml", "plist", "xml", "toml", "ini", "cfg":
            return "doc.text.fill"
        // Documents
        case "pdf":
            return "doc.richtext.fill"
        case "doc", "docx", "pages":
            return "doc.fill"
        case "xls", "xlsx", "numbers", "csv":
            return "tablecells.fill"
        case "ppt", "pptx", "key":
            return "rectangle.on.rectangle.fill"
        // Fonts
        case "ttf", "otf", "woff", "woff2":
            return "textformat"
        default:
            return "doc.fill"
        }
    }
}

// MARK: - Flat elevation modifier

extension View {
    /// Flat elevation: a hairline border on the clipped shape plus a soft,
    /// neutral drop shadow. Replaces the old "Liquid Glass" highlight lip. Kept
    /// the name and signature so existing call sites compile unchanged.
    func liquidGlassDepth<S: InsettableShape>(
        _ shape: S,
        highlight: Double = 1.0,
        shadowRadius: CGFloat = 22,
        shadowY: CGFloat = 14
    ) -> some View {
        self
            .overlay(
                shape
                    .strokeBorder(Theme.border, lineWidth: 1)
                    .allowsHitTesting(false)
            )
            .shadow(color: .black.opacity(0.22), radius: min(shadowRadius, 12), y: min(shadowY, 6))
    }
}

// MARK: - Flat button styles

/// Padding/rounding that tracks `.controlSize(...)`, so the ~30 existing call
/// sites that ask for `.small` or `.large` still get the right proportions.
private struct FlatButtonMetrics {
    let h: CGFloat, v: CGFloat, radius: CGFloat
    init(_ size: ControlSize) {
        switch size {
        case .mini, .small: self.init(h: 9, v: 4, radius: 7)
        case .large, .extraLarge: self.init(h: 18, v: 10, radius: 10)
        default: self.init(h: 14, v: 7, radius: 9)
        }
    }
    private init(h: CGFloat, v: CGFloat, radius: CGFloat) {
        self.h = h; self.v = v; self.radius = radius
    }
}

// MARK: - Interaction feedback
//
// Every interactive surface answers the same two questions: "is this thing
// live?" (hover) and "did my click land?" (press). Before this, the flat styles
// changed only on press and only slightly, and plain icon buttons did nothing at
// all — so neither question was answered.
//
// TesseraButtonModifier observes focus on the Button. A ButtonStyle child's
// isFocused environment does not follow activation focus on this macOS path.
// Text fields and other system controls keep their native focus indication.
// Hover and press feedback add clarity without moving controls under the pointer.

/// Timing shared by every interaction so the whole app feels like one surface.
enum Motion {
    static let hover: Animation = .easeOut(duration: 0.12)
    static let press: Animation = .easeOut(duration: 0.09)
}

/// The hover and press surface behind the flat button styles.
private struct FlatButtonSurface<Label: View>: View {
    let label: Label
    let radius: CGFloat
    let isPressed: Bool
    let resting: Color
    let hovered: Color
    let pressedFill: Color
    let border: Color?
    let borderHovered: Color?
    /// `nil` keeps whatever colour the call site already set on the label — the
    /// plain style must not repaint labels that style themselves.
    let foreground: Color?
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    /// Applies the style's colour only when it owns one, so call sites that set
    /// their own (`.foregroundStyle(.tint)`, danger red, …) keep it.
    @ViewBuilder private var tintedLabel: some View {
        if let foreground { label.foregroundStyle(foreground) } else { label }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let active = isHovering && isEnabled
        // Hover should clarify a control, not move it under the pointer.
        let scale: CGFloat = isPressed ? 0.97 : 1.0
        return tintedLabel
            .background(isPressed ? pressedFill : (active ? hovered : resting), in: shape)
            .overlay {
                if let border {
                    shape.strokeBorder(active ? (borderHovered ?? border) : border, lineWidth: 1)
                }
            }
            .contentShape(shape)
            .scaleEffect(reduceMotion ? 1.0 : scale)
            .opacity(isEnabled ? 1.0 : 0.55)
            .animation(reduceMotion ? nil : Motion.hover, value: isHovering)
            .animation(reduceMotion ? nil : Motion.press, value: isPressed)
            // A pointer cue makes "this is clickable" obvious before the click.
            // Declarative, so it can't unbalance the cursor stack the way
            // NSCursor.push/pop pairs can when views come and go mid-hover.
            .pointerStyle(isEnabled ? .link : nil)
            .onHover { isHovering = $0 }
    }
}

/// Filled accent button (primary action). Solid cyan, contrast-safe ink.
/// Deliberately does not set a font — call sites' `.font()` still applies.
struct FlatProminentButtonStyle: TesseraButtonStyle {
    var tint: Color = Theme.electricBlue
    var ink: Color?
    @Environment(\.controlSize) private var controlSize

    func focusRadius(for size: ControlSize) -> CGFloat { FlatButtonMetrics(size).radius }

    func makeBody(configuration: Configuration) -> some View {
        let m = FlatButtonMetrics(controlSize)
        return FlatButtonSurface(
            label: configuration.label
                .padding(.horizontal, m.h)
                .padding(.vertical, m.v),
            radius: m.radius,
            isPressed: configuration.isPressed,
            resting: tint,
            hovered: tint.opacity(0.88),
            pressedFill: tint.opacity(0.78),
            border: nil,
            borderHovered: nil,
            foreground: ink ?? Theme.ink(on: tint)
        )
    }
}

/// Neutral bordered button (secondary action). Transparent fill, hairline border.
struct FlatButtonStyle: TesseraButtonStyle {
    var tint: Color = Theme.foreground
    @Environment(\.controlSize) private var controlSize

    func focusRadius(for size: ControlSize) -> CGFloat { FlatButtonMetrics(size).radius }

    func makeBody(configuration: Configuration) -> some View {
        let m = FlatButtonMetrics(controlSize)
        return FlatButtonSurface(
            label: configuration.label
                .padding(.horizontal, m.h)
                .padding(.vertical, m.v),
            radius: m.radius,
            isPressed: configuration.isPressed,
            resting: .clear,
            hovered: Color.white.opacity(0.07),
            pressedFill: Color.white.opacity(0.12),
            border: Theme.border,
            borderHovered: Theme.borderStrong,
            foreground: tint
        )
    }
}

/// Bare icon button (sidebar refresh, inspector affordances). Previously
/// `.buttonStyle(.plain)`, which gave no hover or press feedback at all and let
/// macOS draw its system-accent focus ring — the stray pink halo in the sidebar.
struct IconButtonStyle: TesseraButtonStyle {
    var size: CGFloat = 28
    var tint: Color = Theme.mutedForeground

    func focusRadius(for controlSize: ControlSize) -> CGFloat { size / 2 }

    func makeBody(configuration: Configuration) -> some View {
        FlatButtonSurface(
            label: configuration.label.frame(width: max(22, size), height: max(22, size)),
            radius: size / 2,
            isPressed: configuration.isPressed,
            resting: .clear,
            hovered: Color.white.opacity(0.10),
            pressedFill: Color.white.opacity(0.16),
            border: nil,
            borderHovered: nil,
            foreground: tint
        )
    }
}

/// Drop-in replacement for `.plain`, which renders a button as bare content with
/// no hover or press response whatsoever. This keeps that layout exactly — no
/// padding, no background, so nothing shifts — and adds the two cues that were
/// missing: the label brightens under the pointer and settles when clicked.
/// Labels that colour themselves keep their colour.
struct PlainInteractiveButtonStyle: TesseraButtonStyle {
    func focusRadius(for size: ControlSize) -> CGFloat { 6 }

    func makeBody(configuration: Configuration) -> some View {
        PlainInteractiveSurface(label: configuration.label, isPressed: configuration.isPressed)
    }
}

/// The hover and press surface behind `PlainInteractiveButtonStyle`.
private struct PlainInteractiveSurface<Label: View>: View {
    let label: Label
    let isPressed: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        let active = isHovering && isEnabled
        return label
            .frame(minHeight: 22)
            .brightness(active && !isPressed ? 0.12 : 0)
            .opacity(isPressed ? 0.85 : 1.0)
            // Scale down only on press: a hover-grow would reflow full-width rows.
            .scaleEffect(reduceMotion ? 1.0 : (isPressed ? 0.98 : 1.0))
            .animation(reduceMotion ? nil : Motion.hover, value: isHovering)
            .animation(reduceMotion ? nil : Motion.press, value: isPressed)
            .pointerStyle(isEnabled ? .link : nil)
            .onHover { isHovering = $0 }
    }
}

extension ButtonStyle where Self == PlainInteractiveButtonStyle {
    /// Bare button that still answers hover and click.
    static var interactive: PlainInteractiveButtonStyle { .init() }
}

extension ButtonStyle where Self == IconButtonStyle {
    /// Circular, borderless icon button with hover + press feedback.
    static var icon: IconButtonStyle { .init() }
    static func icon(size: CGFloat = 28, tint: Color = Theme.mutedForeground) -> IconButtonStyle {
        .init(size: size, tint: tint)
    }
}

// MARK: - Row interaction

extension View {
    /// Hover + press feedback for list rows and other tappable non-button
    /// surfaces (sidebar sources, duplicate groups, suggestion rows). Selected
    /// rows keep their accent wash and only brighten on hover.
    func interactiveRow(
        isSelected: Bool = false,
        radius: CGFloat = 10,
        pressed: Bool = false
    ) -> some View {
        modifier(InteractiveRow(isSelected: isSelected, radius: radius, pressed: pressed))
    }
}

private struct InteractiveRow: ViewModifier {
    let isSelected: Bool
    let radius: CGFloat
    let pressed: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let active = isHovering && isEnabled
        return content
            .background {
                shape.fill(
                    pressed ? Color.white.opacity(0.10)
                            : (active ? Color.white.opacity(isSelected ? 0.06 : 0.05) : .clear)
                )
            }
            .contentShape(shape)
            .scaleEffect(reduceMotion ? 1.0 : (pressed ? 0.985 : 1.0))
            .animation(reduceMotion ? nil : Motion.hover, value: isHovering)
            .animation(reduceMotion ? nil : Motion.press, value: pressed)
            .pointerStyle(isEnabled ? .link : nil)
            .onHover { isHovering = $0 }
    }
}

extension ButtonStyle where Self == FlatProminentButtonStyle {
    /// Primary filled accent button.
    static var flatProminent: FlatProminentButtonStyle { .init() }
    static func flatProminent(tint: Color, ink: Color? = nil) -> FlatProminentButtonStyle {
        .init(tint: tint, ink: ink)
    }
}

extension ButtonStyle where Self == FlatButtonStyle {
    /// Secondary bordered button.
    static var flat: FlatButtonStyle { .init() }
    static func flat(tint: Color) -> FlatButtonStyle { .init(tint: tint) }
}

protocol TesseraButtonStyle: ButtonStyle {
    func focusRadius(for size: ControlSize) -> CGFloat
}

private struct TesseraButtonModifier<Style: TesseraButtonStyle>: ViewModifier {
    let style: Style
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled
    // A sheet or alert takes key status from the window behind it. Its
    // opener keeps SwiftUI focus, so draw the ring only in the key window.
    @Environment(\.controlActiveState) private var activeState
    @FocusState private var focused: Bool

    private var showsRing: Bool { focused && isEnabled && activeState == .key }

    func body(content: Content) -> some View {
        content.buttonStyle(style)
            .focused($focused)
            .focusEffectDisabled()
            .background(RevealWhenFocused(focused: showsRing))
            .overlay {
                if showsRing {
                    RoundedRectangle(cornerRadius: style.focusRadius(for: controlSize), style: .continuous)
                        .inset(by: -3)
                        .strokeBorder(Theme.electricBlue, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    /// A toolbar icon button in the Tessera icon style, with its cyan ring.
    func toolbarIconButton() -> some View {
        labelStyle(.iconOnly)
            .font(.system(size: 15))
            .tesseraButtonStyle(.icon(size: 28, tint: Theme.foreground))
    }

    /// The Tessera cyan ring on a system control, such as a toolbar menu,
    /// in place of the system ring in the user's accent colour.
    func cyanFocusRing(radius: CGFloat) -> some View {
        modifier(CyanFocusRing(radius: radius))
    }
}

private struct CyanFocusRing: ViewModifier {
    let radius: CGFloat
    @Environment(\.controlActiveState) private var activeState
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .focused($focused)
            .focusEffectDisabled()
            .overlay {
                if focused && activeState == .key {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .inset(by: -3)
                        .strokeBorder(Theme.electricBlue, lineWidth: 2)
                        .allowsHitTesting(false)
                }
            }
    }
}

/// A segmented switch with the Tessera cyan focus ring. It is an AppKit
/// segmented control, so it keeps the radio group role, the selected state,
/// and arrow and Space keys. The system ring is off; the host view draws the
/// cyan one while the control has keyboard focus in the key window.
struct WorkspaceSwitch: NSViewRepresentable {
    let label: String
    let titles: [String]
    @Binding var selection: Int

    final class Segments: NSSegmentedControl {
        var onFocusChange: () -> Void = {}
        override func becomeFirstResponder() -> Bool {
            defer { onFocusChange() }
            return super.becomeFirstResponder()
        }
        override func resignFirstResponder() -> Bool {
            defer { onFocusChange() }
            return super.resignFirstResponder()
        }
    }

    final class Host: NSView {
        let segments = Segments()
        private var observers: [NSObjectProtocol] = []

        override init(frame: NSRect) {
            super.init(frame: frame)
            segments.focusRingType = .none
            segments.onFocusChange = { [weak self] in self?.needsDisplay = true }
            addSubview(segments)
        }
        required init?(coder: NSCoder) { nil }

        override func layout() {
            super.layout()
            let height = segments.intrinsicContentSize.height
            segments.frame = NSRect(x: 4, y: (bounds.height - height) / 2,
                                    width: bounds.width - 8, height: height)
            let width = segments.frame.width / CGFloat(max(segments.segmentCount, 1))
            for index in 0..<segments.segmentCount { segments.setWidth(width - 1, forSegment: index) }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            guard let window else { return }
            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
                observers.append(NotificationCenter.default.addObserver(
                    forName: name, object: window, queue: .main) { [weak self] _ in self?.needsDisplay = true })
            }
        }

        override func draw(_ dirtyRect: NSRect) {
            guard let window, window.isKeyWindow, window.firstResponder === segments else { return }
            let ring = segments.frame.insetBy(dx: -3, dy: -3).insetBy(dx: 1, dy: 1)
            let path = NSBezierPath(roundedRect: ring, xRadius: ring.height / 2, yRadius: ring.height / 2)
            path.lineWidth = 2
            NSColor(Theme.electricBlue).setStroke()
            path.stroke()
        }
    }

    final class Coordinator: NSObject {
        var parent: WorkspaceSwitch
        init(_ parent: WorkspaceSwitch) { self.parent = parent }
        @objc func changed(_ sender: NSSegmentedControl) { parent.selection = sender.selectedSegment }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> Host {
        let host = Host()
        let segments = host.segments
        segments.segmentCount = titles.count
        for (index, title) in titles.enumerated() { segments.setLabel(title, forSegment: index) }
        segments.trackingMode = .selectOne
        segments.segmentStyle = .automatic
        segments.controlSize = .large
        segments.target = context.coordinator
        segments.action = #selector(Coordinator.changed(_:))
        segments.setAccessibilityLabel(label)
        return host
    }

    func updateNSView(_ host: Host, context: Context) {
        context.coordinator.parent = self
        if host.segments.selectedSegment != selection { host.segments.selectedSegment = selection }
        host.segments.isEnabled = context.environment.isEnabled
    }
}

/// Scrolls a control into view when keyboard focus arrives. SwiftUI scroll
/// views on macOS do not follow Tab focus, so a focused control could sit
/// below the fold. Scrolls only on the change to focused, so a user scroll
/// away from a still-focused control is not undone by a later redraw.
private struct RevealWhenFocused: NSViewRepresentable {
    let focused: Bool

    final class Coordinator { var wasFocused = false }

    /// Scrolls on the next run-loop turn, after SwiftUI finishes this update.
    final class RevealView: NSView {
        @objc func reveal() { scrollToVisible(bounds.insetBy(dx: -8, dy: -16)) }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> RevealView { RevealView() }

    func updateNSView(_ view: RevealView, context: Context) {
        defer { context.coordinator.wasFocused = focused }
        guard focused, !context.coordinator.wasFocused else { return }
        view.perform(#selector(RevealView.reveal), with: nil, afterDelay: 0)
    }
}

extension View {
    func tesseraButtonStyle<Style: TesseraButtonStyle>(_ style: Style) -> some View {
        modifier(TesseraButtonModifier(style: style))
    }
}

/// The app icon as decoration. A plain AppKit view draws it and is never an
/// accessibility element. A SwiftUI `Image` or an `NSImageView` stayed in the
/// AX tree, because a parent's `accessibilityHidden(false)` overrode them.
struct DecorativeAppIcon: NSViewRepresentable {
    final class IconView: NSView {
        override func draw(_ dirtyRect: NSRect) {
            NSApplication.shared.applicationIconImage.draw(in: bounds)
        }
        override func isAccessibilityElement() -> Bool { false }
    }

    func makeNSView(context: Context) -> IconView {
        let view = IconView()
        view.setAccessibilityElement(false)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ view: IconView, context: Context) {}
}

/// Scrolls the top of its view into sight once, when the view appears. For
/// content that opens below the fold, such as an expanded Rescue group.
struct RevealOnAppear: NSViewRepresentable {
    /// How much of the top to bring into sight, in points.
    var height: CGFloat = 160

    final class RevealView: NSView {
        var height: CGFloat = 160
        override var isFlipped: Bool { true }
        override func isAccessibilityElement() -> Bool { false }
        @objc func reveal() {
            scrollToVisible(NSRect(x: 0, y: 0, width: bounds.width, height: min(bounds.height, height)))
        }
    }

    func makeNSView(context: Context) -> RevealView {
        let view = RevealView()
        view.height = height
        // After layout, so the view has its final frame.
        view.perform(#selector(RevealView.reveal), with: nil, afterDelay: 0.05)
        return view
    }

    func updateNSView(_ view: RevealView, context: Context) { view.height = height }
}
