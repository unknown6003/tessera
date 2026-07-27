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
    /// neighbours separate. Solid fills; the chart no longer uses glassy radial
    /// shading.
    static let sunburstColors: [Color] = [
        Color(hex: 0x1BE6FF), Color(hex: 0x37E0C8), Color(hex: 0x5B8CFF),
        Color(hex: 0x9E6BFF), Color(hex: 0x5BE36B), Color(hex: 0xFF5CC8),
        Color(hex: 0xFFB13C),
    ]

    /// Hues retained for any HSB-based swatch use; the chart itself now pulls
    /// solid colors from `sunburstColors` via `wedgeColor`.
    static let topHues: [Double] = [
        0.510, 0.575, 0.480, 0.620, 0.540, 0.500,
        0.600, 0.490, 0.560, 0.530, 0.470, 0.590,
    ]

    /// Solid categorical wedge color. `hue` selects into the flat palette (its
    /// index derived from the hue) and `depth` deepens slightly with nesting so
    /// child rings read as a shade of their parent.
    static func wedgeColor(hue: Double, depth: Int) -> Color {
        // Map the legacy hue into a stable palette index.
        let idx = Int((hue * 1000).rounded()) % sunburstColors.count
        let base = sunburstColors[(idx + sunburstColors.count) % sunburstColors.count]
        guard depth > 0 else { return base }
        // Deepen by compositing toward the void for nested rings.
        return base.opacity(max(0.55, 1.0 - Double(depth) * 0.12))
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
            .shadow(color: .black.opacity(0.35), radius: min(shadowRadius, 20), y: min(shadowY, 10))
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
// It also replaces macOS's own focus ring. That ring is drawn in the SYSTEM
// accent colour, which is not necessarily ours (a Mac set to the pink accent
// draws a pink ring around our controls, ignoring `.tint`). We turn the system
// effect off and draw the ring in the app's own accent instead, so keyboard
// focus stays visible — important with Full Keyboard Access — but on-brand.

/// Timing shared by every interaction so the whole app feels like one surface.
enum Motion {
    static let hover: Animation = .easeOut(duration: 0.12)
    static let press: Animation = .easeOut(duration: 0.09)
}

/// The hover / press / focus surface behind the flat button styles.
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
    /// Prominent buttons already read as filled; they lift instead of washing.
    let liftsOnHover: Bool

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
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
        let scale: CGFloat = isPressed ? 0.97 : (active && liftsOnHover ? 1.02 : 1.0)
        return tintedLabel
            .background(isPressed ? pressedFill : (active ? hovered : resting), in: shape)
            .overlay {
                if let border {
                    shape.strokeBorder(active ? (borderHovered ?? border) : border, lineWidth: 1)
                }
            }
            .overlay {
                if isFocused {
                    shape.strokeBorder(Theme.electricBlue.opacity(0.85), lineWidth: 2)
                }
            }
            .contentShape(shape)
            .scaleEffect(reduceMotion ? 1.0 : scale)
            .opacity(isEnabled ? 1.0 : 0.45)
            .animation(reduceMotion ? nil : Motion.hover, value: isHovering)
            .animation(reduceMotion ? nil : Motion.press, value: isPressed)
            .focusEffectDisabled()
            // A pointer cue makes "this is clickable" obvious before the click.
            // Declarative, so it can't unbalance the cursor stack the way
            // NSCursor.push/pop pairs can when views come and go mid-hover.
            .pointerStyle(isEnabled ? .link : nil)
            .onHover { isHovering = $0 }
    }
}

/// Filled accent button (primary action). Solid cyan, contrast-safe ink.
/// Deliberately does not set a font — call sites' `.font()` still applies.
struct FlatProminentButtonStyle: ButtonStyle {
    var tint: Color = Theme.electricBlue
    var ink: Color?
    @Environment(\.controlSize) private var controlSize

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
            foreground: ink ?? Theme.ink(on: tint),
            liftsOnHover: true
        )
    }
}

/// Neutral bordered button (secondary action). Transparent fill, hairline border.
struct FlatButtonStyle: ButtonStyle {
    var tint: Color = Theme.foreground
    @Environment(\.controlSize) private var controlSize

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
            foreground: tint,
            liftsOnHover: false
        )
    }
}

/// Bare icon button (sidebar refresh, inspector affordances). Previously
/// `.buttonStyle(.plain)`, which gave no hover or press feedback at all and let
/// macOS draw its system-accent focus ring — the stray pink halo in the sidebar.
struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 28
    var tint: Color = Theme.mutedForeground

    func makeBody(configuration: Configuration) -> some View {
        FlatButtonSurface(
            label: configuration.label.frame(width: size, height: size),
            radius: size / 2,
            isPressed: configuration.isPressed,
            resting: .clear,
            hovered: Color.white.opacity(0.10),
            pressedFill: Color.white.opacity(0.16),
            border: nil,
            borderHovered: nil,
            foreground: tint,
            liftsOnHover: false
        )
    }
}

/// Drop-in replacement for `.plain`, which renders a button as bare content with
/// no hover or press response whatsoever. This keeps that layout exactly — no
/// padding, no background, so nothing shifts — and adds the two cues that were
/// missing: the label brightens under the pointer and settles when clicked.
/// Labels that colour themselves keep their colour.
struct PlainInteractiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        let active = isHovering && isEnabled
        return configuration.label
            .brightness(active && !configuration.isPressed ? 0.12 : 0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            // Scale down only on press: a hover-grow would reflow full-width rows.
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.98 : 1.0))
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Theme.electricBlue.opacity(0.85), lineWidth: 2)
                        .padding(-3)
                }
            }
            .animation(reduceMotion ? nil : Motion.hover, value: isHovering)
            .animation(reduceMotion ? nil : Motion.press, value: configuration.isPressed)
            .focusEffectDisabled()
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
