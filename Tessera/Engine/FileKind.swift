import Foundation

// MARK: - File-kind classification
//
// A pure-CPU lens over the assembled tree: it buckets every regular file by what
// it *is* (image, video, audio, …) using only the filename extension — no `stat`,
// no filesystem touch, no content sniffing. The "By Kind" view uses this to answer
// "what's actually eating my disk — photos, video, or app bundles?" at a glance.

/// A coarse content category for a file, inferred from its extension.
enum FileKind: String, CaseIterable, Sendable, Identifiable {
    case image
    case video
    case audio
    case document
    case archive
    case app
    case code
    case other

    var id: String { rawValue }

    /// Human-readable title for the category.
    var title: String {
        switch self {
        case .image:    return "Images"
        case .video:    return "Video"
        case .audio:    return "Audio"
        case .document: return "Documents"
        case .archive:  return "Archives"
        case .app:      return "Apps & Packages"
        case .code:     return "Code"
        case .other:    return "Other"
        }
    }

    /// SF Symbol representing the category.
    var symbol: String {
        switch self {
        case .image:    return "photo.fill"
        case .video:    return "film.fill"
        case .audio:    return "music.note"
        case .document: return "doc.text.fill"
        case .archive:  return "archivebox.fill"
        case .app:      return "app.fill"
        case .code:     return "chevron.left.forwardslash.chevron.right"
        case .other:    return "doc.fill"
        }
    }

    // MARK: Classification

    /// Lowercased extension (no dot) → kind. Anything unrecognized is `.other`.
    /// Pass the bare extension, e.g. "jpg" (a leading dot is tolerated).
    static func classify(extension ext: String) -> FileKind {
        let e = ext.hasPrefix(".") ? String(ext.dropFirst()).lowercased() : ext.lowercased()
        return extensionMap[e] ?? .other
    }

    /// Classify a node. Packages (.app/.framework/…) are `.app` regardless of the
    /// extension table; everything else is keyed off the filename's extension.
    static func classify(node: FileNode) -> FileKind {
        if node.kind == .package { return .app }
        return classify(extension: (node.name as NSString).pathExtension)
    }

    // MARK: Aggregation

    /// One regular file's contribution to a kind breakdown.
    struct Tally: Sendable { var bytes: Int64 = 0; var count: Int = 0 }

    /// Walk the tree (regular files only, skipping synthetic nodes) and aggregate
    /// allocated bytes + count by kind. Directories are descended but never
    /// themselves counted, except packages, which are taken as a single `.app`
    /// unit (their contents are not double-counted underneath). Sorted by bytes
    /// descending; empty kinds are omitted.
    static func breakdown(root: FileNode) -> [(kind: FileKind, bytes: Int64, count: Int)] {
        var tallies: [FileKind: Tally] = [:]

        func add(_ kind: FileKind, bytes: Int64) {
            tallies[kind, default: Tally()].bytes += bytes
            tallies[kind, default: Tally()].count += 1
        }

        // Iterative pre-order walk to avoid deep recursion on large trees.
        var stack: [FileNode] = [root]
        while let node = stack.popLast() {
            for child in node.children where !child.isSynthetic {
                if child.kind == .package {
                    // A package is one unit; count it and don't descend.
                    add(.app, bytes: child.size)
                } else if child.isDirectory {
                    stack.append(child)
                } else {
                    add(classify(node: child), bytes: child.size)
                }
            }
        }

        return tallies
            .map { (kind: $0.key, bytes: $0.value.bytes, count: $0.value.count) }
            .sorted { $0.bytes > $1.bytes }
    }

    /// The largest `limit` regular files of this kind in the tree, bytes-descending.
    /// Packages count as `.app` and are not descended; synthetic nodes are skipped.
    static func largestFiles(of kind: FileKind, in root: FileNode, limit: Int) -> [FileNode] {
        var matches: [FileNode] = []
        var stack: [FileNode] = [root]
        while let node = stack.popLast() {
            for child in node.children where !child.isSynthetic {
                if child.kind == .package {
                    if kind == .app { matches.append(child) }
                } else if child.isDirectory {
                    stack.append(child)
                } else if classify(node: child) == kind {
                    matches.append(child)
                }
            }
        }
        return Array(matches.sorted { $0.size > $1.size }.prefix(limit))
    }

    // MARK: - Extension table

    private static let extensionMap: [String: FileKind] = {
        var m: [String: FileKind] = [:]
        func map(_ kind: FileKind, _ exts: [String]) { for e in exts { m[e] = kind } }

        map(.image, ["jpg", "jpeg", "png", "gif", "heic", "heif", "tiff", "tif", "bmp",
                     "webp", "svg", "raw", "cr2", "cr3", "nef", "arw", "dng", "psd", "ai",
                     "ico", "icns", "avif", "jp2"])
        map(.video, ["mov", "mp4", "m4v", "avi", "mkv", "wmv", "flv", "webm", "mpg", "mpeg",
                     "m2v", "mts", "m2ts", "3gp", "prores", "braw", "r3d", "vob", "ogv"])
        map(.audio, ["mp3", "aac", "wav", "aiff", "aif", "flac", "m4a", "ogg", "wma", "alac",
                     "opus", "mid", "midi", "caf", "amr"])
        map(.document, ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "key", "numbers",
                        "pages", "txt", "rtf", "md", "epub", "mobi", "csv", "tex", "odt",
                        "ods", "odp"])
        map(.archive, ["zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar", "dmg", "pkg",
                       "iso", "cab", "z", "lz", "lzma", "zst", "war", "jar"])
        map(.code, ["swift", "c", "h", "cpp", "cc", "hpp", "m", "mm", "java", "kt", "js",
                    "jsx", "ts", "tsx", "py", "rb", "go", "rs", "php", "cs", "sh", "bash",
                    "zsh", "pl", "lua", "sql", "json", "xml", "yaml", "yml", "toml", "html",
                    "css", "scss", "vue", "dart", "scala", "groovy", "gradle"])
        return m
    }()
}
