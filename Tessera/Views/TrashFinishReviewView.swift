import SwiftUI
import AppKit

struct TrashFinishReviewView: View {
    @ObservedObject var vm: ScanViewModel
    let snapshot: ScanViewModel.TrashFinishReview
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<UUID> = []
    @State private var confirming = false
    @State private var working = false
    @State private var failure: String?
    @State private var consumed = false
    @State private var finishTask: Task<Void, Never>?

    private var current: Bool {
        !consumed && snapshot.source == vm.scannedURL
            && (vm.selectedSourceURL == nil || vm.selectedSourceURL == snapshot.source)
            && snapshot.rootID == vm.rootNode?.id && snapshot.revision == vm.chartRevision
            && vm.hasTrackedTrash && !vm.isScanning && !vm.isDeleting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Finish this cleanup").font(.title2.weight(.semibold))
            Text("These items are already in Trash. Select only what you want to remove permanently. Other Trash items stay untouched.")
                .font(.subheadline).foregroundStyle(Theme.mutedForeground)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(snapshot.review.items) { row in
                        Toggle(isOn: Binding(
                            get: { selected.contains(row.id) },
                            set: { if $0 { selected.insert(row.id) } else { selected.remove(row.id) } }
                        )) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.item.originalURL.lastPathComponent).font(.headline)
                                Text(row.item.originalURL.path).font(.caption).textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let hold = row.hold {
                                    Text(Self.message(hold)).font(.caption).foregroundStyle(Theme.mutedForeground)
                                    Button("Inspect held item in Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([row.recoveryURL ?? row.item.trashURL])
                                    }.tesseraButtonStyle(.flat).controlSize(.small)
                                } else {
                                    Text("\(Theme.format(snapshot.allocatedBytes[row.id] ?? 0)) allocated")
                                        .font(.caption.monospacedDigit()).foregroundStyle(Theme.mutedForeground)
                                }
                            }
                        }
                        .toggleStyle(.checkbox)
                        .disabled(row.hold != nil || !current || working)
                    }
                }.padding(.vertical, 4)
            }.frame(maxHeight: 310)
            ForEach(vm.trashFinishIssues) { issue in
                VStack(alignment: .leading, spacing: 3) {
                    Text(issue.message).font(.caption)
                    Button("Inspect \(issue.trashURL.lastPathComponent) in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([issue.trashURL])
                    }.tesseraButtonStyle(.flat).controlSize(.small)
                }
            }
            if !current && !working && !consumed {
                Text("The scan or source changed. Close this review and check the items again.")
                    .font(.caption).foregroundStyle(Theme.mutedForeground)
            }
            if let failure { Text(failure).font(.caption).foregroundStyle(Theme.mutedForeground) }
            Text("Removal cannot be undone. Allocated bytes do not promise the same increase in free space.")
                .font(.caption).foregroundStyle(Theme.mutedForeground)
            HStack {
                Button(working ? "Stop after current item" : "Close") {
                    if working { finishTask?.cancel() } else { dismiss() }
                }.tesseraButtonStyle(.flat).keyboardShortcut(.cancelAction)
                Spacer()
                if working { ProgressView().controlSize(.small) }
                Button("Remove \(Theme.itemCount(selected.count)) permanently…") { confirming = true }
                    .tesseraButtonStyle(.flat)
                    .disabled(selected.isEmpty || !current || working)
            }
        }
        .padding(24).frame(width: 560).background(Theme.bg)
        .onDisappear { finishTask?.cancel() }
        .alert("Permanently remove \(Theme.itemCount(selected.count))?", isPresented: $confirming) {
            Button("Cancel", role: .cancel) {}.keyboardShortcut(.defaultAction)
            Button("Remove permanently", role: .destructive) { finish() }
        } message: {
            Text("Only the selected, unchanged items from this cleanup will be removed. You cannot undo this.")
        }
    }

    private func finish() {
        guard current, !selected.isEmpty, !working else { return }
        working = true
        finishTask = Task {
            do {
                try await vm.finishTrackedTrash(snapshot, selecting: selected)
                consumed = true
                working = false
                if vm.trashFinishIssues.isEmpty { dismiss() }
            } catch {
                failure = error.localizedDescription
                working = false
            }
        }
    }

    private static func message(_ hold: TrashOperation.Hold) -> String {
        switch hold {
        case .changed: return "Held: this item changed, moved or was restored."
        case .protectedContents: return "Held: protected content needs its owner app."
        case .ownerUnverified: return "Held: quit the owner app, then review again."
        case .incomplete: return "Held: the whole item could not be checked."
        case .cancelled: return "Held: checking was cancelled."
        case .wrongOperation, .staleReview: return "Held: close this review and check again."
        case .unavailable: return "Held: this item could not be verified. Use Finder to inspect it."
        }
    }
}
