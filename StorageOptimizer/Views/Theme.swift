import SwiftUI
import AppKit

enum Theme {

    // MARK: - Hues

    /// 12 vivid hues evenly spaced starting from red-orange (DaisyDisk-style).
    /// Adjacent entries are ~30° apart on the colour wheel for clear contrast.
    static let topHues: [Double] = (0..<12).map { i in
        // Start at 0.02 (red-orange) and step 1/12 (~0.0833) each time.
        (0.02 + Double(i) * (1.0 / 12.0)).truncatingRemainder(dividingBy: 1.0)
    }

    // MARK: - Wedge colours

    /// HSB-based wedge colour. depth 0 = innermost ring (most vivid).
    static func wedgeColor(hue: Double, depth: Int) -> Color {
        let saturation = max(0.45, 0.88 - Double(depth) * 0.08)
        let brightness  = max(0.55, 0.92 - Double(depth) * 0.06)
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// Glassy gradient fill for a wedge — a bright specular inner edge bleeding
    /// into a translucent, slightly desaturated body so the luminous backdrop
    /// refracts through the ring. Outer rings read as thinner, cooler glass.
    static func wedgeGradient(hue: Double, depth: Int) -> AnyShapeStyle {
        // Bright specular highlight near the inner edge (top-leading).
        let specular = Color(hue: hue,
                             saturation: max(0.18, 0.55 - Double(depth) * 0.07),
                             brightness: min(1.0,  1.02 - Double(depth) * 0.03))
        // Saturated body.
        let body = wedgeColor(hue: hue, depth: depth)
        // Cooler, more translucent shadow side so depth reads through the glass.
        let shadow = Color(hue: hue,
                           saturation: min(1.0, 0.92 - Double(depth) * 0.05),
                           brightness: max(0.40, 0.66 - Double(depth) * 0.05))
            .opacity(0.92)
        return AnyShapeStyle(
            LinearGradient(
                stops: [
                    .init(color: specular.opacity(0.96), location: 0.00),
                    .init(color: body,                    location: 0.42),
                    .init(color: shadow,                  location: 1.00),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    /// A thin bright "rim light" colour for a wedge's inner specular edge,
    /// drawn as a stroke in the Canvas for a refracted-glass lip.
    static func wedgeRim(hue: Double, depth: Int) -> Color {
        Color(hue: hue,
              saturation: max(0.10, 0.40 - Double(depth) * 0.06),
              brightness: 1.0)
    }

    // MARK: - Synthetic node colours

    /// Translucent frosted neutral for "Hidden Space" (space the scan cannot see).
    static let hiddenSpaceColor: Color = Color(
        NSColor(calibratedWhite: 0.62, alpha: 0.42)
    )

    /// Translucent frosted neutral for aggregated "Other" slices.
    static let aggregateColor: Color = Color(
        NSColor(calibratedWhite: 0.50, alpha: 0.34)
    )

    /// Soft luminous cyan for online-only cloud-storage boundary nodes.
    static let cloudColor: Color = Color(hue: 0.54, saturation: 0.42, brightness: 0.92)

    // MARK: - Background

    /// Primary luminous backdrop — a deep indigo/teal multi-stop radial gradient
    /// giving the floating glass something vivid to refract. Layer the
    /// `backgroundBlobs` view on top of this for chromatic depth.
    static var backgroundGradient: AnyShapeStyle {
        AnyShapeStyle(
            RadialGradient(
                stops: [
                    .init(color: Color(hue: 0.60, saturation: 0.42, brightness: 0.30), location: 0.00),
                    .init(color: Color(hue: 0.66, saturation: 0.55, brightness: 0.20), location: 0.45),
                    .init(color: Color(hue: 0.71, saturation: 0.62, brightness: 0.12), location: 0.80),
                    .init(color: Color(hue: 0.74, saturation: 0.70, brightness: 0.06), location: 1.00),
                ],
                center: UnitPoint(x: 0.38, y: 0.30),
                startRadius: 0,
                endRadius: 1100
            )
        )
    }

    /// Soft, large, blurred colour "blobs" that sit behind the glass panels to
    /// create chromatic depth showing through translucent surfaces. Animated by a
    /// slow phase so the light gently drifts.
    static func backgroundBlobs(phase: Double) -> some View {
        let drift = sin(phase) * 26
        let drift2 = cos(phase * 0.8) * 30
        return ZStack {
            blob(color: Color(hue: 0.58, saturation: 0.85, brightness: 0.95), // cyan-blue
                 size: 620, opacity: 0.34)
                .offset(x: -260 + drift, y: -200 - drift2)
            blob(color: Color(hue: 0.80, saturation: 0.80, brightness: 0.95), // violet
                 size: 560, opacity: 0.30)
                .offset(x: 320 + drift2, y: -130 + drift)
            blob(color: Color(hue: 0.50, saturation: 0.80, brightness: 0.92), // teal
                 size: 520, opacity: 0.24)
                .offset(x: 200 - drift, y: 280 + drift2)
            blob(color: Color(hue: 0.92, saturation: 0.70, brightness: 0.92), // magenta
                 size: 460, opacity: 0.20)
                .offset(x: -300 - drift2, y: 240 - drift)
        }
        .blur(radius: 80)
        .blendMode(.screen)
    }

    private static func blob(color: Color, size: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(opacity), color.opacity(0.0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
    }

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
