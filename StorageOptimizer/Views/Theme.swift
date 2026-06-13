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

    /// Linear gradient fill — lighter inner edge fading to the base wedge colour.
    static func wedgeGradient(hue: Double, depth: Int) -> AnyShapeStyle {
        let base   = wedgeColor(hue: hue, depth: depth)
        let bright = Color(hue: hue,
                           saturation: max(0.30, 0.70 - Double(depth) * 0.08),
                           brightness: min(1.0,  1.00 - Double(depth) * 0.04))
        return AnyShapeStyle(
            LinearGradient(
                colors: [bright, base],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    // MARK: - Synthetic node colours

    /// Translucent neutral for "Hidden Space" (space the scan cannot see).
    static let hiddenSpaceColor: Color = Color(
        NSColor(calibratedWhite: 0.55, alpha: 0.55)
    )

    /// Translucent neutral for aggregated "Other" slices.
    static let aggregateColor: Color = Color(
        NSColor(calibratedWhite: 0.45, alpha: 0.45)
    )

    // MARK: - Background

    /// Deep slate→indigo radial gradient backdrop — the canvas the glass panels float on.
    static var backgroundGradient: AnyShapeStyle {
        AnyShapeStyle(
            RadialGradient(
                stops: [
                    .init(color: Color(hue: 0.63, saturation: 0.30, brightness: 0.22), location: 0.00),
                    .init(color: Color(hue: 0.68, saturation: 0.45, brightness: 0.16), location: 0.55),
                    .init(color: Color(hue: 0.72, saturation: 0.55, brightness: 0.10), location: 1.00),
                ],
                center: .center,
                startRadius: 0,
                endRadius: 800
            )
        )
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
