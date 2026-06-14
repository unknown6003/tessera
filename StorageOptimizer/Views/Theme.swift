import SwiftUI
import AppKit

enum Theme {

    // MARK: - Hues

    /// Soft pastel palette for the top ring. The chart is now a light, airy glass
    /// pane floating over the desktop, so the wedges use gentle, low-saturation
    /// hues — blush, sky, peach, lavender, mint — instead of the old saturated
    /// jewel tones, which read as garish against the translucent theme. Entries
    /// are interleaved warm/cool so adjacent siblings still contrast.
    static let topHues: [Double] = [
        0.96,  // blush rose
        0.55,  // sky blue
        0.08,  // peach
        0.72,  // lavender
        0.14,  // butter
        0.48,  // mint
        0.86,  // lilac
        0.58,  // powder blue
        0.03,  // coral
        0.78,  // soft violet
        0.42,  // sage
        0.17,  // warm sand
    ]

    // MARK: - Wedge colours

    /// HSB-based wedge colour for legend/icon swatches. Kept soft and pastel —
    /// low saturation, high brightness — to match the chart. depth 0 = innermost.
    static func wedgeColor(hue: Double, depth: Int) -> Color {
        let saturation = max(0.16, 0.34 - Double(depth) * 0.04)
        let brightness  = min(0.97, 0.86 + Double(depth) * 0.02)
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// Coherent pastel radial palette for a wedge, lit from the chart centre:
    /// luminous and near-white on the inner edge, gently deepening toward the
    /// rim. Paired with a `GraphicsContext` radial shading centred on the hub so
    /// every ring shares ONE light direction. Saturation rises only slightly
    /// outward — just enough to separate adjacent rings — keeping the whole chart
    /// light, flowy and glassy rather than vivid.
    static func wedgeRadialGradient(hue: Double) -> Gradient {
        Gradient(stops: [
            .init(color: Color(hue: hue, saturation: 0.22, brightness: 0.99), location: 0.00),
            .init(color: Color(hue: hue, saturation: 0.34, brightness: 0.93), location: 0.50),
            .init(color: Color(hue: hue, saturation: 0.46, brightness: 0.84), location: 1.00),
        ])
    }

    /// A thin bright "rim light" colour for a wedge's inner specular edge,
    /// drawn as a stroke in the Canvas for a refracted-glass lip.
    static func wedgeRim(hue: Double, depth: Int) -> Color {
        Color(hue: hue,
              saturation: max(0.04, 0.16 - Double(depth) * 0.03),
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

    /// Soft pastel cyan for online-only cloud-storage boundary nodes.
    static let cloudColor: Color = Color(hue: 0.54, saturation: 0.24, brightness: 0.98)

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

    /// A subtle tint used to brighten selected glass (selection = brighter glass,
    /// not an opaque fill).
    static let selectionTint = Color.accentColor.opacity(0.22)

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
        case .package:
            let ext = node.url.pathExtension.lowercased()
            switch ext {
            case "app":       return "app.fill"
            case "framework", "dylib", "bundle": return "shippingbox.fill"
            case "plugin", "kext": return "puzzlepiece.extension.fill"
            default:          return "shippingbox.fill"
            }
        case .regular:
            if node.isDirectory { return "folder.fill" }
            let ext = node.url.pathExtension.lowercased()
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
