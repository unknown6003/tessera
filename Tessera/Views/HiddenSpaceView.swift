import SwiftUI
import AppKit

/// Breaks the opaque "Hidden Space" wedge into what it's actually made of —
/// purgeable caches, APFS local snapshots, protected files — and lets the user
/// reclaim the parts that are safe to clear and choose which snapshots to keep.
struct HiddenSpaceView: View {
    @ObservedObject var vm: ScanViewModel
    let hiddenBytes: Int64

    @State private var report: HiddenSpaceReport?
    @State private var status: String?
    @State private var busyID: String?
    /// Snapshot deletion is irreversible, so — like every other destructive
    /// action in the app — it is confirmed first.
    @State private var confirmDeleteAll = false
    @State private var snapToDelete: LocalSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHAT'S IN HERE")
                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary).kerning(0.8)
                .padding(.top, 2)

            if let report {
                Text("Space the volume uses that the scan can't list directly. Here's what it's made of and what's safe to reclaim.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                purgeableRow(report)
                snapshotsSection(report)
                if !report.hasFullDiskAccess { fdaRow }
                otherRow(report)
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).scaleEffect(0.8)
                    Text("Analyzing hidden space…").font(.caption).foregroundStyle(.secondary)
                }
            }

            if let status {
                Text(status).font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task(id: hiddenBytes) { await reload() }
        .confirmationDialog(
            "Delete all \(report?.snapshots.count ?? 0) local snapshots?",
            isPresented: $confirmDeleteAll,
            titleVisibility: .visible
        ) {
            Button("Delete All Snapshots", role: .destructive) {
                Task { await deleteAll() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This frees space immediately and cannot be undone. You won't be able to restore this Mac to these earlier points in time.")
        }
        .confirmationDialog(
            "Delete this snapshot?",
            isPresented: Binding(
                get: { snapToDelete != nil },
                set: { if !$0 { snapToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Snapshot", role: .destructive) {
                if let snap = snapToDelete {
                    snapToDelete = nil
                    Task { await delete(snap) }
                }
            }
            Button("Cancel", role: .cancel) { snapToDelete = nil }
        } message: {
            Text("This cannot be undone. You won't be able to restore this Mac to that earlier point in time.")
        }
    }

    // MARK: Rows

    @ViewBuilder
    private func purgeableRow(_ r: HiddenSpaceReport) -> some View {
        categoryRow(icon: "sparkles", color: .cyan, title: "Space macOS frees on its own",
                    detail: Theme.format(r.purgeableBytes),
                    note: "Caches macOS reclaims automatically when your disk runs low (\"purgeable\" space). Nothing for you to do.")
    }

    @ViewBuilder
    private func snapshotsSection(_ r: HiddenSpaceReport) -> some View {
        if r.snapshots.isEmpty {
            categoryRow(icon: "clock.arrow.circlepath", color: .orange, title: "Backup snapshots",
                        detail: "None", note: "No Time Machine backup snapshots are stored on this disk.")
        } else {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath").font(.caption).foregroundStyle(.orange).frame(width: 18)
                Text("Backup snapshots").font(.subheadline.weight(.medium))
                Text("\(r.snapshots.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                Button("Delete all…") { confirmDeleteAll = true }
                    .buttonStyle(.flat).controlSize(.small)
                    .disabled(busyID != nil)
            }
            Text("Time Machine keeps recent backups on this disk itself. Deleting them frees space, but you lose the ability to roll back to those points in time — keeping the most recent one is usually wise.")
                .font(.caption2).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
            ForEach(r.snapshots) { snap in
                HStack(spacing: 8) {
                    Image(systemName: "camera.aperture").font(.caption2).foregroundStyle(.secondary).frame(width: 14)
                    Text(snapLabel(snap)).font(.caption).lineLimit(1)
                    Spacer()
                    if busyID == snap.id {
                        ProgressView().controlSize(.small).scaleEffect(0.7)
                    } else {
                        Button { snapToDelete = snap } label: {
                            Image(systemName: "trash").font(.caption2)
                        }
                        .buttonStyle(.plain).foregroundStyle(Theme.danger)
                        .help("Delete this snapshot — cannot be undone")
                        .disabled(busyID != nil)
                    }
                }
            }
        }
    }

    private var fdaRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            categoryRow(icon: "lock.shield", color: .yellow, title: "Protected files",
                        detail: nil,
                        note: "Some hidden space is files the scan can't read without Full Disk Access. Grant it, then rescan to see and clean them.")
            Button { vm.openFullDiskAccessSettings() } label: {
                Label("Open Full Disk Access settings", systemImage: "gearshape")
                    .font(.caption.weight(.medium))
            }
            .buttonStyle(.flat).controlSize(.small)
        }
    }

    @ViewBuilder
    private func otherRow(_ r: HiddenSpaceReport) -> some View {
        let other = max(0, r.otherBytes)
        categoryRow(icon: "internaldrive", color: .gray, title: "Other system data",
                    detail: Theme.format(other),
                    note: "Time Machine and system data macOS manages. Reduced by clearing snapshots above.")
    }

    @ViewBuilder
    private func categoryRow(icon: String, color: Color, title: String, detail: String?, note: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption).foregroundStyle(color).frame(width: 18)
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                if let detail {
                    Text(detail).font(.caption.monospacedDigit().weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            Text(note).font(.caption2).foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }

    // MARK: Actions

    private func reload() async {
        guard let vol = vm.scannedURL else { return }
        let bytes = hiddenBytes
        let r = await Task.detached { HiddenSpaceAnalyzer.analyze(volumeURL: vol, hiddenBytes: bytes) }.value
        report = r
    }

    private func delete(_ snap: LocalSnapshot) async {
        busyID = snap.id
        status = nil
        let ok = await Task.detached { HiddenSpaceAnalyzer.deleteSnapshot(snap) }.value
        busyID = nil
        status = ok ? "Deleted \(snapLabel(snap)). Rescan to refresh totals."
                    : "Couldn't delete that snapshot — it may require administrator rights."
        await reload()
    }

    private func deleteAll() async {
        guard let snaps = report?.snapshots else { return }
        busyID = "all"
        status = nil
        var failed = 0
        for snap in snaps {
            let ok = await Task.detached { HiddenSpaceAnalyzer.deleteSnapshot(snap) }.value
            if !ok { failed += 1 }
        }
        busyID = nil
        status = failed == 0 ? "Deleted all snapshots. Rescan to refresh totals."
                             : "\(failed) snapshot(s) couldn't be deleted — may require administrator rights."
        await reload()
    }

    private func snapLabel(_ snap: LocalSnapshot) -> String {
        guard let date = snap.date else { return snap.dateToken ?? snap.name }
        let f = DateFormatter()
        f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: date)
    }
}
