import SwiftUI
import AppKit

/// The Rescue task surface: one ranked list of storage consumers, largest
/// allocated footprint first. A group opens for review in this same area.
/// Nothing here removes a file.
struct CleanupSuggestionsView: View {
    @ObservedObject var vm: ScanViewModel
    /// Shows the in-page review button. The caller passes it only when the
    /// window's Cleanup List dock, which has its own filled review button, is
    /// not on screen, so the window never shows two filled review buttons.
    var onMoveToTrash: (() -> Void)?
    /// Opens the parent's separate, operation-scoped Trash finishing step.
    /// The parent passes it only while that step can be safely reviewed.
    var onFinishTrash: (() -> Void)?

    @StateObject private var workspace: RescueWorkspaceModel
    @FocusState private var focusedRow: String?
    @State private var goalDraft = ""
    @State private var isEditingGoal = false

    init(vm: ScanViewModel, onMoveToTrash: (() -> Void)? = nil, onFinishTrash: (() -> Void)? = nil) {
        self.vm = vm
        self.onMoveToTrash = onMoveToTrash
        self.onFinishTrash = onFinishTrash
        _workspace = StateObject(wrappedValue: RescueWorkspaceModel(vm: vm))
    }

    /// For a parent that owns the coordinator, so a pending owner return and
    /// the Back position survive switching between Explore and Rescue.
    init(vm: ScanViewModel, workspace: RescueWorkspaceModel,
         onMoveToTrash: (() -> Void)? = nil, onFinishTrash: (() -> Void)? = nil) {
        self.vm = vm
        self.onMoveToTrash = onMoveToTrash
        self.onFinishTrash = onFinishTrash
        _workspace = StateObject(wrappedValue: workspace)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let review = workspace.review {
                RescueReviewView(vm: vm, workspace: workspace, review: review)
            } else if workspace.showsExcluded {
                excludedView
            } else {
                if vm.rescuePlan == nil, let saved = vm.savedRescueCase {
                    savedCaseRow(saved, showsPath: true)
                }
                if let plan = vm.rescuePlan {
                    resultsView(plan)
                    if let onMoveToTrash, !vm.collector.isEmpty {
                        reviewFooter(onMoveToTrash)
                    }
                } else {
                    emptyPlan
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if vm.rescuePlan != nil { vm.beginRescueReview() }
        }
    }

    // MARK: Results

    @ViewBuilder
    private func resultsView(_ plan: RescuePlan) -> some View {
        header(plan)
        if let saved = vm.savedRescueCase {
            savedCaseRow(saved, showsPath: saved.sourcePath != plan.sourcePath)
        }
        statusLines(plan)

        if let verification = vm.rescueVerification {
            verificationCard(verification)
        } else if let error = vm.lastRescueError {
            resultErrorCard(error)
        }

        listControls
        rankedList
        unmeasuredFindings(plan)
        excludedLink
    }

    private func header(_ plan: RescuePlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Rescue space")
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text("\(URL(fileURLWithPath: plan.sourcePath).lastPathComponent) · checked \(plan.measurement.measuredAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(plan.sourcePath)
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 24) { capacityFigures(plan.measurement) }
                    .fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: 8) { capacityFigures(plan.measurement) }
            }
            goalLine
            DisclosureGroup("About these figures") {
                Text("Available for use includes space macOS can reclaim from caches and other purgeable files. Free now is space that is free at this moment. Both cover the whole drive that holds this source. Sizes in the list are allocated space for the scanned source only. Moving items to the Trash does not free space until the Trash is emptied.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private func capacityFigures(_ measurement: RescueMeasurement) -> some View {
        if let available = measurement.availableBytes {
            metric("Available for use", Theme.format(available))
        }
        metric("Free now", measurement.freeBytes.map(Theme.format) ?? "Unknown")
    }

    // MARK: Goal

    @ViewBuilder
    private var goalLine: some View {
        if isEditingGoal {
            HStack(spacing: 8) {
                Text("Free up")
                    .font(.subheadline)
                TextField("GB", text: $goalDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .accessibilityLabel("Additional gigabytes to free")
                    .onSubmit(commitGoal)
                Text("more GB")
                    .font(.subheadline)
                Button("Set", action: commitGoal)
                    .tesseraButtonStyle(.flat)
                    .controlSize(.small)
                    .disabled(parsedGoal == nil)
                Button("Cancel") { isEditingGoal = false }
                    .tesseraButtonStyle(.flat)
                    .controlSize(.small)
            }
        } else if let goal = workspace.goal {
            HStack(spacing: 8) {
                Text(goalText(goal))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(goalColor(goal))
                    .fixedSize(horizontal: false, vertical: true)
                Button("Check again") { workspace.checkGoal() }
                    .tesseraButtonStyle(.flat)
                    .controlSize(.small)
                Button("Clear goal") { workspace.clearGoal() }
                    .tesseraButtonStyle(.flat)
                    .controlSize(.small)
            }
        } else {
            Button("Set a space goal") {
                goalDraft = ""
                isEditingGoal = true
            }
            .tesseraButtonStyle(.flat)
            .controlSize(.small)
            .accessibilityHint("Measures added free space on this drive from now.")
        }
    }

    private var parsedGoal: Double? {
        let value = Double(goalDraft.replacingOccurrences(of: ",", with: "."))
        return value.flatMap { $0 > 0 && $0 < 100_000 ? $0 : nil }
    }

    private func commitGoal() {
        guard let value = parsedGoal else { return }
        workspace.setGoal(additionalGB: value)
        isEditingGoal = false
    }

    private func goalText(_ goal: RescueSpaceGoal) -> String {
        let target = Theme.format(goal.additionalBytes)
        let time = goal.latest.checkedAt.formatted(date: .omitted, time: .shortened)
        switch goal.status {
        case .unverified(let reason):
            return "Goal: \(target) more free. Not verified. \(reason)"
        case .progress(let change, let remaining):
            let sign = change < 0 ? "−" : "+"
            return "Goal: \(target) more free. Free now changed \(sign)\(Theme.format(abs(change))) since you set it, \(Theme.format(remaining)) to go. Checked \(time)."
        case .reached(let change):
            return "Goal reached: Free now is up \(Theme.format(change)). Checked \(time). Other apps can also change this figure."
        }
    }

    private func goalColor(_ goal: RescueSpaceGoal) -> Color {
        switch goal.status {
        case .unverified: return .orange
        case .progress: return .primary
        case .reached: return Theme.electricBlue
        }
    }

    // MARK: Status

    @ViewBuilder
    private func statusLines(_ plan: RescuePlan) -> some View {
        if vm.isScanning {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Checking again. The list shows the result from \(plan.measurement.measuredAt.formatted(date: .omitted, time: .shortened)).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Cancel") { vm.cancelScan() }
                    .tesseraButtonStyle(.flat)
                    .controlSize(.small)
            }
        }
        switch workspace.handoff {
        case .none:
            EmptyView()
        case .waiting(let owner), .deferred(let owner):
            HStack(spacing: 8) {
                Text("Opened \(owner). Tessera checks this source once when you return.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Don't check") { workspace.cancelHandoff() }
                    .tesseraButtonStyle(.flat)
                    .controlSize(.small)
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            Button("Retry") { Task { await workspace.retryOwnerHandoff() } }
                .tesseraButtonStyle(.flat).controlSize(.small)
                .disabled(workspace.isOpeningOwner)
        }
        if plan.coverage.state != .complete {
            VStack(alignment: .leading, spacing: 4) {
                Label(plan.coverage.title + ". Known items are shown; some areas were not checked.",
                      systemImage: plan.coverage.state == .blocked ? "lock.fill" : "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        if let notice = workspace.reviewNotice {
            Text(notice)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func unmeasuredFindings(_ plan: RescuePlan) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Not measured").font(.headline).accessibilityAddTraits(.isHeader)
            Text("Snapshot and purgeable recovery is not measured by this file scan. These findings are not added to allocated totals.")
                .font(.caption).foregroundStyle(Theme.mutedForeground)
            ForEach(plan.coverage.notes, id: \.self) { note in
                Text(note).font(.caption).foregroundStyle(Theme.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
            Button("Inspect snapshots in Disk Utility") {
                let route = RescueOwnerRoute.route(categoryID: "owner.snapshots", path: "")
                Task { await workspace.openOwner(route, revealing: []) }
            }.tesseraButtonStyle(.flat).controlSize(.small)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Ranked list

    private var listControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                filterPicker
                Spacer(minLength: 8)
                searchField
            }
            VStack(alignment: .leading, spacing: 8) {
                filterPicker
                searchField
            }
        }
    }

    private var filterPicker: some View {
        Picker("Show", selection: $workspace.filter) {
            ForEach(RescueFilter.allCases) { filter in
                Text("\(filter.title) \(workspace.count(for: filter))").tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .accessibilityLabel("Show groups")
    }

    private var searchField: some View {
        TextField("Search groups", text: $workspace.searchText)
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 140, maxWidth: 220)
            .accessibilityLabel("Search groups on this Mac")
    }

    @ViewBuilder
    private var rankedList: some View {
        let rows = workspace.visibleRows
        if workspace.rows.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nothing to suggest")
                    .font(.headline)
                Text("This scan found no known large storage consumers in the checked areas.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        } else if rows.isEmpty {
            Text("No groups match this filter or search.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rows) { row in
                    groupRow(row)
                    Divider()
                }
            }
            .overlay(alignment: .top) { Divider() }
            .onAppear {
                if let id = workspace.returnGroupID, rows.contains(where: { $0.id == id }) {
                    focusedRow = id
                }
            }
        }
    }

    private func groupRow(_ row: RescueGroupRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: row.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(row.kind == .managed ? Theme.mutedForeground : Theme.electricBlue)
                .frame(width: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                Text(ownerLine(row))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(row.reason)
                    .font(.callout)
                    .foregroundStyle(Theme.mutedForeground)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("If removed: \(row.effect)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            VStack(alignment: .trailing, spacing: 6) {
                Text(Theme.format(row.bytes))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .accessibilityLabel("\(Theme.format(row.bytes)) allocated")
                Button(row.actionTitle) { workspace.openReview(row) }
                    .tesseraButtonStyle(.flat)
                    .controlSize(.small)
                    .fixedSize()
                    .focused($focusedRow, equals: row.id)
                    .disabled(workspace.isOpeningReview)
                    .accessibilityLabel("\(row.actionTitle) in \(row.title)")
            }
        }
        .padding(.vertical, 12)
        .background {
            if workspace.returnGroupID == row.id { RevealOnAppear(height: 120) }
        }
    }

    private func ownerLine(_ row: RescueGroupRow) -> String {
        var line = "\(row.owner) · \(Theme.itemCount(row.itemCount))"
        if row.kind == .managed { line += " · managed by its app" }
        if row.keptCount > 0 { line += " · \(row.keptCount) kept" }
        return line
    }

    @ViewBuilder
    private var excludedLink: some View {
        let kept = workspace.keptForCurrentSource.count
        if kept > 0 {
            Button("Show excluded (\(kept))") { workspace.showsExcluded = true }
                .tesseraButtonStyle(.flat)
                .controlSize(.small)
                .accessibilityLabel("Show \(kept) kept items")
        }
    }

    // MARK: Excluded

    private var excludedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { workspace.showsExcluded = false } label: {
                Label("Back to Rescue", systemImage: "chevron.left")
            }
            .tesseraButtonStyle(.flat)
            .controlSize(.small)
            .keyboardShortcut("[", modifiers: .command)

            Text("Kept items")
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text("Rescue hides these on this Mac. A different item at the same path is not hidden.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let kept = workspace.keptForCurrentSource
            if kept.isEmpty {
                Text("No kept items for this source.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(kept) { item in
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(URL(fileURLWithPath: item.path).lastPathComponent)
                            .font(.callout.weight(.semibold))
                        Text(item.path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        if !workspace.isResolved(item) {
                            Text("Not in this scan. It may have moved, changed or been replaced. It does not hide a new item.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Restore suggestion") { workspace.restore(item) }
                        .tesseraButtonStyle(.flat)
                        .controlSize(.small)
                        .fixedSize()
                        .accessibilityLabel("Restore \(URL(fileURLWithPath: item.path).lastPathComponent) to Rescue")
                }
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) { Divider() }
            }
        }
    }

    // MARK: Empty

    private var emptyPlan: some View {
        VStack(alignment: .leading, spacing: 10) {
            FeatureSectionLabel("Rescue space")
            if vm.isScanning {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text("Checking this source…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Cancel") { vm.cancelScan() }
                        .tesseraButtonStyle(.flat)
                        .controlSize(.small)
                }
            } else if let error = vm.lastRescueError ?? vm.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                if vm.canRetryLastScan {
                    Button("Retry") { vm.retryLastScan() }
                        .tesseraButtonStyle(.flatProminent)
                        .controlSize(.regular)
                }
            } else if let source = vm.selectedSourceURL {
                Text("Find what uses the most space on this source. Tessera reads files on this Mac and moves nothing while it checks.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Scan") { vm.startScan(volumeURL: source) }
                    .tesseraButtonStyle(.flatProminent)
                    .controlSize(.regular)
                    .disabled(vm.isDeleting)
                    .accessibilityLabel("Scan \(source.lastPathComponent)")
            } else {
                Text("Choose a drive or folder in the sidebar to scan.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func reviewFooter(_ moveToTrash: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Cleanup List")
                    .font(.subheadline.weight(.semibold))
                Text("\(Theme.itemCount(vm.collector.count)) · \(Theme.format(vm.collectorTotalSize)) staged. Nothing has moved yet.")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button { moveToTrash() } label: {
                Label("Review Cleanup List…", systemImage: "checklist")
            }
            .tesseraButtonStyle(.flatProminent)
            .controlSize(.regular)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Divider() }
    }

    private func verificationCard(_ verification: RescueVerification) -> some View {
        let color: Color = verification.hasMeasurementMismatch || verification.failedBytes > 0
            ? .orange : Theme.electricBlue

        return VStack(alignment: .leading, spacing: 8) {
            Label(verification.status,
                  systemImage: verification.hasMeasurementMismatch
                    ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(color)

            if let error = vm.lastRescueError {
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) {
                    verificationMetrics(verification)
                }
                .fixedSize(horizontal: true, vertical: false)

                VStack(alignment: .leading, spacing: 8) {
                    verificationMetrics(verification)
                }
            }

            Text(verification.recoveryNote)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let requested = verification.requestedBytes {
                Text("Requested usable space: \(Theme.format(requested))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let onFinishTrash, verification.removalMethod != .permanent {
                Button("Finish these Trash items…", action: onFinishTrash)
                    .tesseraButtonStyle(.flat)
                    .controlSize(.small)
                    .help("Review only the items this move put in the Trash before removing them for good.")
            }

            pathDisclosure(title: verification.removalMethod == .permanent ? "Deleted paths" : "Moved paths", paths: verification.movedPaths)
            pathDisclosure(title: "Held paths", paths: verification.heldPaths)
            pathDisclosure(title: "Paths that did not match", paths: verification.measurementMismatchPaths)
            pathDisclosure(title: "Failed paths", paths: verification.failedPaths)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Divider() }
    }

    @ViewBuilder
    private func verificationMetrics(_ verification: RescueVerification) -> some View {
        metric(verification.removalTitle, Theme.format(verification.movedBytes))
        metric("Failed", Theme.format(verification.failedBytes))
        if let reclaimed = verification.verifiedReclaimedBytes {
            metric(verification.hasMeasurementMismatch ? "Measured change" : "Verified change",
                   Theme.format(reclaimed))
        }
    }

    @ViewBuilder
    private func pathDisclosure(title: String, paths: [String]?) -> some View {
        if let paths, !paths.isEmpty {
            DisclosureGroup(title) {
                ForEach(paths, id: \.self) { path in
                    Text(path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            .font(.caption)
        }
    }

    private func resultErrorCard(_ error: String) -> some View {
        Label(error, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) { Divider() }
    }

    /// A compact banner: one line of status with its two actions, the path
    /// only when the header does not already show it.
    private func savedCaseRow(_ saved: SavedRescueCase, showsPath: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    savedCaseTitle
                    Spacer(minLength: 8)
                    savedCaseActions
                }
                VStack(alignment: .leading, spacing: 6) {
                    savedCaseTitle
                    savedCaseActions
                }
            }

            if showsPath {
                Text(saved.sourcePath)
                    .font(.caption.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
            }

            if vm.restoredRescueCaseIsStale {
                Text("The old selection no longer matches the fresh scan. Review it again before staging.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if !vm.restoredRescueCandidateIDs.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(vm.restoredRescueCandidateIDs.count) old selection\(vm.restoredRescueCandidateIDs.count == 1 ? "" : "s") found again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Stage for review") { vm.stageRestoredRescueCase() }
                        .tesseraButtonStyle(.flat)
                        .controlSize(.small)
                }
                Text("Nothing is staged until you choose this action.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var savedCaseTitle: some View {
        HStack(spacing: 8) {
            Image(systemName: "bookmark.fill")
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Saved rescue case. Rescan before staging anything.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var savedCaseActions: some View {
        HStack(spacing: 8) {
            // Flat: a saved case is a secondary path; the page keeps one
            // filled primary action.
            Button("Reopen and rescan") { vm.reopenSavedRescueCase() }
                .tesseraButtonStyle(.flat)
                .controlSize(.small)
                .disabled(vm.isScanning)
            Button("Forget") { vm.discardSavedRescueCase() }
                .tesseraButtonStyle(.flat)
                .controlSize(.small)
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
