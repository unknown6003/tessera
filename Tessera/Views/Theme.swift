import SwiftUI
import AppKit

enum Theme {

    // MARK: - Signature colour

    /// The app's signature colour: electric blue (#00F0FF). Drives the global
    /// tint, selection, progress and the anchor of the chart palette.
    static let electricBlue = Color(red: 0.0, green: 240.0 / 255.0, blue: 1.0)
    /// Hue of `electricBlue` in the 0…1 wheel (~183.5°) — the centre of the
    /// wedge palette band.
    static let electricBlueHue: Double = 183.5 / 360.0

    /// Signature gradient for everything premium / AI — the visual marker that
    /// separates paid AI features from the free, built-in tools.
    static let aiGradient = LinearGradient(
        colors: [electricBlue, Color(red: 0.62, green: 0.35, blue: 1.0)],
        startPoint: .leading, endPoint: .trailing)

    /// Deep electric-blue-tinted wash laid over the frosted window base. Gives the
    /// glass a cool cyan cast instead of a flat grey, tying the whole pane to the
    /// accent. Applied at low opacity (see `GlassTuning.baseTint`).
    static let windowTint = Color(hue: electricBlueHue, saturation: 0.65, brightness: 0.11)

    // MARK: - Hues

    /// Electric-blue chart palette for the top ring. Every entry sits in a tight
    /// cyan→blue band around `electricBlueHue`, so the whole chart reads as one
    /// coherent electric-blue family rather than the old garish rainbow. Adjacent
    /// siblings still separate because the hue drifts slightly and the radial
    /// shading varies brightness; entries are interleaved so neighbours differ.
    static let topHues: [Double] = [
        0.510,  // electric cyan (signature)
        0.575,  // azure
        0.480,  // turquoise
        0.620,  // blue
        0.540,  // sky
        0.500,  // bright cyan
        0.600,  // cornflower
        0.490,  // aqua
        0.560,  // cerulean
        0.530,  // cyan
        0.470,  // teal-cyan
        0.590,  // periwinkle blue
    ]

    // MARK: - Wedge colours

    /// HSB-based wedge colour for legend/icon swatches — vivid electric blue,
    /// deepening a touch with depth. depth 0 = innermost.
    static func wedgeColor(hue: Double, depth: Int) -> Color {
        let saturation = min(0.95, 0.62 + Double(depth) * 0.06)
        let brightness  = max(0.78, 0.98 - Double(depth) * 0.04)
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// Coherent electric-blue radial palette for a wedge, lit from the chart
    /// centre: a luminous near-white-cyan inner edge deepening to saturated
    /// electric blue at the rim. Paired with a `GraphicsContext` radial shading
    /// centred on the hub so every ring shares ONE light direction — vivid and
    /// glassy rather than flat.
    static func wedgeRadialGradient(hue: Double) -> Gradient {
        Gradient(stops: [
            .init(color: Color(hue: hue, saturation: 0.45, brightness: 1.00), location: 0.00),
            .init(color: Color(hue: hue, saturation: 0.72, brightness: 0.96), location: 0.50),
            .init(color: Color(hue: hue, saturation: 0.95, brightness: 0.82), location: 1.00),
        ])
    }

    /// A thin bright "rim light" colour for a wedge's inner specular edge,
    /// drawn as a stroke in the Canvas for a refracted-glass lip.
    static func wedgeRim(hue: Double, depth: Int) -> Color {
        Color(hue: hue,
              saturation: max(0.06, 0.22 - Double(depth) * 0.03),
              brightness: 1.0)
    }

    // MARK: - Synthetic node colours

    /// Translucent frosted neutral for "Hidden Space" (space the scan cannot see).
    static let hiddenSpaceColor: Color = Color(
        NSColor(calibratedWhite: 0.80, alpha: 0.32)
    )

    /// Translucent frosted neutral for aggregated "Other" slices.
    static let aggregateColor: Color = Color(
        NSColor(calibratedWhite: 0.72, alpha: 0.24)
    )

    /// Pale, desaturated electric-cyan for online-only cloud-storage boundary
    /// nodes — same family as the wedges but washed-out so it reads as "not local".
    static let cloudColor: Color = Color(hue: electricBlueHue, saturation: 0.20, brightness: 1.0)

    /// Amber for cross-mounted volumes (Simulator runtimes, mounted images) — a
    /// distinct, slightly warning-ish hue so this reclaimable-but-not-a-file space
    /// stands apart from both real files and grey hidden space.
    static let crossVolumeColor: Color = Color(hue: 0.10, saturation: 0.55, brightness: 1.0)

    // MARK: - Glass tints & strokes

    /// Faint top-highlight stroke gradient that gives glass a "thick" refracting
    /// lip — bright at the top, fading to nothing at the bottom.
    static var glassHighlightStroke: LinearGradient {
        LinearGradient(
            colors: [.white.opacity(0.55), .white.opacity(0.06), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// A subtle electric-blue tint used to brighten selected glass (selection =
    /// brighter glass, not an opaque fill).
    static let selectionTint = electricBlue.opacity(0.22)

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

// MARK: - Glass depth modifiers

extension View {
    /// Adds the "thick Liquid Glass" finish to a shape-clipped surface: a faint
    /// bright top-highlight lip plus a soft ambient drop shadow for floating
    /// depth. Apply *after* `.glassEffect(_:in:)` using the same shape.
    func liquidGlassDepth<S: InsettableShape>(
        _ shape: S,
        highlight: Double = 1.0,
        shadowRadius: CGFloat = 22,
        shadowY: CGFloat = 14
    ) -> some View {
        self
            .overlay(
                shape
                    .strokeBorder(Theme.glassHighlightStroke, lineWidth: 1)
                    .opacity(highlight)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            )
            .shadow(color: .black.opacity(0.28), radius: shadowRadius, y: shadowY)
    }
}
