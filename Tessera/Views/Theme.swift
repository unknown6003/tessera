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

/// Filled accent button (primary action). Solid cyan, contrast-safe ink.
/// Deliberately does not set a font — call sites' `.font()` still applies.
struct FlatProminentButtonStyle: ButtonStyle {
    var tint: Color = Theme.electricBlue
    var ink: Color?
    @Environment(\.controlSize) private var controlSize

    func makeBody(configuration: Configuration) -> some View {
        let m = FlatButtonMetrics(controlSize)
        let shape = RoundedRectangle(cornerRadius: m.radius, style: .continuous)
        return configuration.label
            .foregroundStyle(ink ?? Theme.ink(on: tint))
            .padding(.horizontal, m.h)
            .padding(.vertical, m.v)
            .background(tint.opacity(configuration.isPressed ? 0.82 : 1.0), in: shape)
            .contentShape(shape)
    }
}

/// Neutral bordered button (secondary action). Transparent fill, hairline border.
struct FlatButtonStyle: ButtonStyle {
    var tint: Color = Theme.foreground
    @Environment(\.controlSize) private var controlSize

    func makeBody(configuration: Configuration) -> some View {
        let m = FlatButtonMetrics(controlSize)
        let shape = RoundedRectangle(cornerRadius: m.radius, style: .continuous)
        return configuration.label
            .foregroundStyle(tint)
            .padding(.horizontal, m.h)
            .padding(.vertical, m.v)
            .background(Color.white.opacity(configuration.isPressed ? 0.10 : 0.0), in: shape)
            .overlay(shape.strokeBorder(Theme.border, lineWidth: 1))
            .contentShape(shape)
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
