import Foundation
import AppKit
import NetFS

// MARK: - Storage source kind

/// What a scannable source *is* — drives the sidebar grouping, icon and label.
enum StorageSourceKind: String, Sendable, CaseIterable {
    case internalDisk
    case external
    case cloud
    case network
    case folder

    /// Sidebar section heading.
    var sectionTitle: String {
        switch self {
        case .internalDisk: return "This Mac"
        case .external:     return "External"
        case .cloud:        return "Cloud"
        case .network:      return "Network"
        case .folder:       return "Folders"
        }
    }

    /// Top-to-bottom section order in the sidebar.
    var sortRank: Int {
        switch self {
        case .internalDisk: return 0
        case .external:     return 1
        case .cloud:        return 2
        case .network:      return 3
        case .folder:       return 4
        }
    }

    var symbolName: String {
        switch self {
        case .internalDisk: return "internaldrive"
        case .external:     return "externaldrive"
        case .cloud:        return "cloud"
        case .network:      return "network"
        case .folder:       return "folder"
        }
    }
}

// MARK: - VolumeInfo

/// A scannable storage source: a physical disk, an external/removable drive, a
/// cloud provider folder, a mounted network share, or a hand-picked folder.
struct VolumeInfo: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let kind: StorageSourceKind
    /// Secondary descriptor — filesystem ("SMB"), cloud account, "Removable", …
    let subtitle: String?
    let totalBytes: Int64?
    let availableBytes: Int64?

    var usedBytes: Int64? {
        guard let t = totalBytes, let a = availableBytes else { return nil }
        return max(0, t - a)
    }

    static func == (lhs: VolumeInfo, rhs: VolumeInfo) -> Bool { lhs.url == rhs.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }

    init(url: URL, name: String, kind: StorageSourceKind, subtitle: String? = nil,
         totalBytes: Int64? = nil, availableBytes: Int64? = nil) {
        self.url = url
        self.name = name
        self.kind = kind
        self.subtitle = subtitle
        self.totalBytes = totalBytes
        self.availableBytes = availableBytes
    }

    /// A folder the user chose by hand.
    init(folderURL: URL) {
        self.init(url: folderURL, name: folderURL.lastPathComponent, kind: .folder)
    }
}

// MARK: - Discovery

/// Enumerates everything scannable: mounted volumes (internal/external/network),
/// File-Provider cloud folders (Google Drive, OneDrive, Dropbox, Nextcloud, …)
/// and iCloud Drive. Network shares the user hasn't mounted yet are reached via
/// `NetworkShareMounter`.
enum StorageSourceDiscovery {
    static func discover() -> [VolumeInfo] {
        var seen = Set<URL>()
        return (mountedVolumes() + cloudProviders())
            .filter { seen.insert($0.url.standardizedFileURL).inserted }
    }

    // MARK: Mounted volumes

    private static let volumeKeys: [URLResourceKey] = [
        .volumeNameKey, .volumeIsRemovableKey, .volumeIsEjectableKey,
        .volumeIsLocalKey, .volumeIsInternalKey,
        .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
    ]

    static func mountedVolumes() -> [VolumeInfo] {
        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: volumeKeys,
            options: [.skipHiddenVolumes]
        ) ?? []

        return urls.compactMap { url -> VolumeInfo? in
            guard let vals = try? url.resourceValues(forKeys: Set(volumeKeys)) else { return nil }
            let name = vals.volumeName ?? url.lastPathComponent
            let total = vals.volumeTotalCapacity.map(Int64.init)
            let avail = vals.volumeAvailableCapacity.map(Int64.init)

            let isLocal = vals.volumeIsLocal ?? true
            let isRemovable = (vals.volumeIsRemovable ?? false) || (vals.volumeIsEjectable ?? false)
            let net = networkLabel(forFSType: filesystemType(for: url))

            let kind: StorageSourceKind
            let subtitle: String?
            if net != nil || !isLocal {
                kind = .network
                subtitle = net ?? "Network"
            } else if isRemovable {
                kind = .external
                subtitle = "Removable"
            } else {
                kind = .internalDisk
                subtitle = nil
            }

            return VolumeInfo(url: url, name: name, kind: kind, subtitle: subtitle,
                              totalBytes: total, availableBytes: avail)
        }
    }

    // MARK: Cloud providers

    static func cloudProviders() -> [VolumeInfo] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        var result: [VolumeInfo] = []

        // Modern macOS File-Provider mounts: ~/Library/CloudStorage/<Provider>-<account>
        let cloudStorage = home.appending(path: "Library/CloudStorage")
        if let entries = try? fm.contentsOfDirectory(
            at: cloudStorage, includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]) {
            for entry in entries {
                let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                guard isDir else { continue }
                let (provider, account) = parseCloudFolderName(entry.lastPathComponent)
                result.append(VolumeInfo(url: entry, name: provider, kind: .cloud, subtitle: account))
            }
        }

        // iCloud Drive lives outside CloudStorage.
        let iCloud = home.appending(path: "Library/Mobile Documents/com~apple~CloudDocs")
        if fm.fileExists(atPath: iCloud.path) {
            result.append(VolumeInfo(url: iCloud, name: "iCloud Drive", kind: .cloud, subtitle: "Apple"))
        }

        return result
    }

    /// Splits "GoogleDrive-john@gmail.com" into ("Google Drive", "john@gmail.com").
    static func parseCloudFolderName(_ raw: String) -> (provider: String, account: String?) {
        let parts = raw.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let token = String(parts.first ?? "")
        let account = parts.count > 1 ? String(parts[1]) : nil
        return (prettyProviderName(token), account?.isEmpty == true ? nil : account)
    }

    private static let knownProviders: [String: String] = [
        "GoogleDrive": "Google Drive",
        "OneDrive": "OneDrive",
        "Dropbox": "Dropbox",
        "Box": "Box",
        "Nextcloud": "Nextcloud",
        "ownCloud": "ownCloud",
        "ProtonDrive": "Proton Drive",
        "pCloud": "pCloud",
        "Egnyte": "Egnyte",
        "Sync": "Sync.com",
    ]

    static func prettyProviderName(_ token: String) -> String {
        if let known = knownProviders[token] { return known }
        // Split camelCase ("SomeProvider" → "Some Provider") as a sane fallback.
        let spaced = token.replacingOccurrences(
            of: "([a-z0-9])([A-Z])", with: "$1 $2", options: .regularExpression)
        return spaced.isEmpty ? token : spaced
    }

    // MARK: Filesystem probing

    /// The volume's BSD filesystem name via `statfs` (e.g. "apfs", "smbfs", "nfs").
    static func filesystemType(for url: URL) -> String? {
        var s = statfs()
        guard statfs(url.path, &s) == 0 else { return nil }
        return withUnsafeBytes(of: &s.f_fstypename) { raw -> String? in
            guard let base = raw.baseAddress else { return nil }
            return String(cString: base.assumingMemoryBound(to: CChar.self))
        }
    }

    /// Maps a network filesystem name to a friendly protocol label, or nil if local.
    static func networkLabel(forFSType fs: String?) -> String? {
        guard let fs = fs?.lowercased() else { return nil }
        switch fs {
        case "smbfs":            return "SMB"
        case "nfs":              return "NFS"
        case "afpfs":            return "AFP"
        case "webdav":           return "WebDAV"
        case "ftp":              return "FTP"
        case let f where f.contains("smb"): return "SMB"
        case let f where f.contains("nfs"): return "NFS"
        case let f where f.contains("webdav"): return "WebDAV"
        default:                 return nil
        }
    }
}

// MARK: - Network share mounting

/// Mounts arbitrary network shares (smb://, nfs://, afp://, http(s):// WebDAV)
/// via the system NetFS API, prompting for credentials with the standard dialog
/// when the share isn't anonymous.
enum NetworkShareMounter {
    enum MountError: LocalizedError {
        case invalidURL
        case mountFailed(Int32)
        case noMountPoint

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Enter a valid address such as smb://server/share or nfs://host/export."
            case .mountFailed(let code):
                return "Could not connect to the server (error \(code)). Check the address, your network, and your credentials."
            case .noMountPoint:
                return "The server connected but reported no mount point."
            }
        }
    }

    /// Mounts `urlString` and returns the local mount point. Runs the blocking
    /// NetFS call off the main thread.
    static func mount(_ urlString: String) async throws -> URL {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty,
              url.host != nil else {
            throw MountError.invalidURL
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var mountpoints: Unmanaged<CFArray>?
                // Allow the system credential dialog for non-anonymous shares.
                let openOptions = NSMutableDictionary()
                openOptions[kNAUIOptionKey] = kNAUIOptionAllowUI

                let status = NetFSMountURLSync(
                    url as CFURL, nil, nil, nil,
                    openOptions as CFMutableDictionary, nil, &mountpoints)

                guard status == 0 else {
                    continuation.resume(throwing: MountError.mountFailed(status))
                    return
                }
                let mounts = mountpoints?.takeRetainedValue() as? [String]
                if let first = mounts?.first {
                    continuation.resume(returning: URL(fileURLWithPath: first))
                } else {
                    continuation.resume(throwing: MountError.noMountPoint)
                }
            }
        }
    }
}
