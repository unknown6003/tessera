import SwiftUI
import AppKit

/// The first Rescue slice. It explains the current measurement and ranks every
/// known candidate without hiding protected owner-managed paths.
struct CleanupSuggestionsView: View {
    @ObservedObject var vm: ScanViewModel

    @State private var requiredSpaceText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FeatureSectionLabel("Rescue space")

            if let saved = vm.savedRescueCase {
                savedCaseRow(saved)
            }

            if let plan = vm.rescuePlan {
                planView(plan)
            } else {
                emptyPlan
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if vm.rescuePlan != nil { vm.beginRescueReview() }
            syncRequiredSpaceText()
        }
        .onChange(of: vm.rescuePlan?.sourcePath) { _, _ in syncRequiredSpaceText() }
    }

    @ViewBuilder
    private func planView(_ plan: RescuePlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("A short plan for \(plan.sourcePath)")
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
                .truncationMode(.middle)
            Label(vm.rescuePhase.title, systemImage: vm.rescuePhase.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color(for: plan.coverage.state == .blocked ? .protected : .safe))

            goalCard(plan)
            measurementCard(plan)

            if let verification = vm.rescueVerification {
                verificationCard(verification)
            } else if let error = vm.lastRescueError {
                resultErrorCard(error)
            }

            coverageCard(plan.coverage)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ranked candidates")
                        .font(.subheadline.weight(.semibold))
                    Text("Safe items are staged for review. Check every exact path before moving anything.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Save plan") { vm.saveRescueCase() }
                    .buttonStyle(.flat)
                    .controlSize(.small)
                    .help("Save this plan on this Mac. It will not move files.")
            }

            if let report = vm.cleanupReport, !report.isEmpty {
                if !report.safeGroups.isEmpty {
                    Button {
                        vm.stageSafeCleanup()
                    } label: {
                        Label("Add all safe · \(Theme.format(report.safeTotalBytes))",
                              systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.flatProminent)
                    .controlSize(.large)
                    .disabled(vm.safeGroupsAllStaged)
                }

                ForEach(report.groups) { group in
                    groupRow(group)
                }
            } else {
                Text("No known candidates in this scan. The coverage and measurement above still matter.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emptyPlan: some View {
        VStack(alignment: .leading, spacing: 8) {
            if vm.isScanning {
                ProgressView("Building the rescue plan…")
            } else if let error = vm.lastRescueError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Label("Scan a source to build a plan.", systemImage: "magnifyingglass")
                    .font(.subheadline)
                Text("Rescue reads local storage only. It does not move or upload files while it measures.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func goalCard(_ plan: RescuePlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What do you need room for?")
                .font(.caption.weight(.semibold))

            Picker("Goal", selection: Binding(
                get: { vm.rescueGoal },
                set: { vm.updateRescueGoal($0, requiredSpace: parsedRequiredSpace) }
            )) {
                ForEach(RescueGoal.allCases, id: \.self) { goal in
                    Text(goal.title).tag(goal)
                }
            }
            .labelsHidden()

            HStack(spacing: 8) {
                TextField("Target GB (optional)", text: $requiredSpaceText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(commitRequiredSpace)
                Text("+ \(Theme.format(plan.workingSpaceBuffer)) working room")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            if let target = plan.targetSpace {
                Text("Plan target: \(Theme.format(target)) usable space, including temporary work room.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Theme.border, lineWidth: 1))
    }

    private func measurementCard(_ plan: RescuePlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                metric("Available", plan.measurement.availableBytes.map(Theme.format) ?? "Unknown")
                metric("Free", plan.measurement.freeBytes.map(Theme.format) ?? "Unknown")
            }
            HStack(spacing: 14) {
                metric("Logical", Theme.format(plan.measurement.logicalBytes))
                metric("Physical", Theme.format(plan.measurement.physicalBytes))
            }
            Text("Source: \(plan.measurement.primarySource) · measured locally")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Theme.border, lineWidth: 1))
    }

    private func verificationCard(_ verification: RescueVerification) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(verification.status,
                  systemImage: verification.hasMeasurementMismatch
                    ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(verification.hasMeasurementMismatch ? .orange : Theme.electricBlue)
            if let error = vm.lastRescueError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let requested = verification.requestedBytes {
                Text("Requested usable space: \(Theme.format(requested))")
                    .font(.caption2)
            }
            Text("Moved from this plan: \(Theme.format(verification.movedBytes))")
                .font(.caption2)
            Text("Moved to Finder Trash (still on disk): \(Theme.format(verification.movedBytes))")
                .font(.caption2)
            if let movedPaths = verification.movedPaths, !movedPaths.isEmpty {
                DisclosureGroup("Moved paths") {
                    ForEach(movedPaths, id: \.self) { path in
                        Text(path)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
                .font(.caption2)
            }
            if let heldBytes = verification.heldBytes, heldBytes > 0 {
                Text("Held for separate review: \(Theme.format(heldBytes))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let heldPaths = verification.heldPaths, !heldPaths.isEmpty {
                DisclosureGroup("Held paths") {
                    ForEach(heldPaths, id: \.self) { path in
                        Text(path)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
                .font(.caption2)
            }
            if let reclaimed = verification.verifiedReclaimedBytes {
                Text("\(verification.hasMeasurementMismatch ? "Measured" : "Verified") usable space change: \(Theme.format(reclaimed))")
                    .font(.caption2)
            } else {
                Text("Usable space could not be verified from the volume measurement.")
                    .font(.caption2)
            }
            if let mismatchPaths = verification.measurementMismatchPaths, !mismatchPaths.isEmpty {
                Text("Space did not match the moved estimate for:")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                ForEach(mismatchPaths, id: \.self) { path in
                    Text(path)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
            if verification.failedBytes > 0 {
                Text("Failed items: \(Theme.format(verification.failedBytes))")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                ForEach(verification.failedPaths, id: \.self) { path in
                    Text(path)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(verification.hasMeasurementMismatch ? .orange.opacity(0.35) : Theme.electricBlue.opacity(0.35), lineWidth: 1))
    }

    private func resultErrorCard(_ error: String) -> some View {
        Label(error, systemImage: "exclamationmark.triangle.fill")
            .font(.caption2)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func coverageCard(_ coverage: RescueCoverage) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(coverage.title, systemImage: coverage.state == .blocked
                  ? "lock.fill" : (coverage.state == .complete
                                    ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(coverage.state == .blocked
                                 ? Theme.danger
                                 : (coverage.state == .complete ? Theme.electricBlue : .orange))
            if coverage.notes.isEmpty {
                Text("No scan gaps reported.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            ForEach(coverage.notes, id: \.self) { note in
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(coverage.state == .complete
                          ? Theme.electricBlue.opacity(0.35)
                          : .orange.opacity(0.35), lineWidth: 1))
    }

    @ViewBuilder
    private func groupRow(_ group: CleanupReport.Group) -> some View {
        DisclosureGroup {
            ForEach(group.recommendations) { recommendation in
                recommendationRow(recommendation)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: group.category.symbol)
                    .frame(width: 20)
                    .foregroundStyle(color(for: group.risk))
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.category.title)
                        .font(.subheadline.weight(.medium))
                    Text("\(group.nodes.count) item\(group.nodes.count == 1 ? "" : "s") · \(group.risk.title)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Text(Theme.format(group.totalBytes))
                    .font(.caption.monospacedDigit().weight(.semibold))
                if group.risk != .protected {
                    Button(vm.isGroupStaged(group) ? "Added" : "Add") {
                        vm.toggleCleanupGroup(group)
                    }
                    .buttonStyle(.flat)
                    .controlSize(.small)
                    .tint(vm.isGroupStaged(group) ? Theme.electricBlue : nil)
                } else {
                    Text("Owner handoff")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .tint(color(for: group.risk))
    }

    private func recommendationRow(_ recommendation: CleanupRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: Theme.icon(for: recommendation.node))
                    .foregroundStyle(color(for: recommendation.risk))
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.path)
                        .font(.caption2.monospaced())
                        .lineLimit(2)
                        .truncationMode(.middle)
                    Text(sizeSummary(for: recommendation))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                if recommendation.risk != .protected {
                    Button(vm.isCollected(recommendation.node) ? "Added" : "Add") {
                        if vm.isCollected(recommendation.node) {
                            vm.removeFromCollector(recommendation.node)
                        } else {
                            vm.addToCollector(recommendation.node)
                        }
                    }
                    .buttonStyle(.flat)
                    .controlSize(.small)
                }
            }
            Text(recommendation.reason)
                .font(.caption2)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Side effect: \(recommendation.sideEffect)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Confidence: \(recommendation.confidence.title) · Next: \(recommendation.action.title)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            DisclosureGroup("Proof") {
                ForEach(recommendation.proof, id: \.self) { item in
                    Text(item)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption2)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([recommendation.node.url])
            } label: {
                Label("Reveal in Finder", systemImage: "magnifyingglass")
            }
        }
    }

    private func savedCaseRow(_ saved: SavedRescueCase) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("Saved rescue case", systemImage: "bookmark.fill")
                .font(.caption.weight(.semibold))
            Text(saved.sourcePath)
                .font(.caption2.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
            HStack {
                Button("Reopen and rescan") { vm.reopenSavedRescueCase() }
                    .buttonStyle(.flat)
                    .controlSize(.small)
                    .disabled(vm.isScanning)
                Button("Forget") { vm.discardSavedRescueCase() }
                    .buttonStyle(.flat)
                    .controlSize(.small)
            }
            if vm.restoredRescueCaseIsStale {
                Text("The old selection no longer matches the fresh scan. Review it again before staging.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            } else if !vm.restoredRescueCandidateIDs.isEmpty {
                HStack {
                    Text("\(vm.restoredRescueCandidateIDs.count) old selection(s) found again.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Stage for review") { vm.stageRestoredRescueCase() }
                        .buttonStyle(.flat)
                        .controlSize(.small)
                }
                Text("Nothing is staged until you choose this action.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Theme.electricBlue.opacity(0.3), lineWidth: 1))
    }

    private func color(for risk: CleanupRisk) -> Color {
        switch risk {
        case .safe: return Theme.electricBlue
        case .review: return .orange
        case .protected: return .secondary
        }
    }

    private func sizeSummary(for recommendation: CleanupRecommendation) -> String {
        let physical = "\(Theme.format(recommendation.physicalBytes)) allocated"
        let logical = recommendation.logicalBytes.map { " · \(Theme.format($0)) logical" } ?? ""
        return "Owner: \(recommendation.owner) · \(physical)\(logical)"
    }

    private var parsedRequiredSpace: Int64? {
        let value = requiredSpaceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let number = Double(value), number.isFinite, number >= 0,
              number <= Double(Int64.max) / 1_000_000_000 else { return nil }
        return Int64(number * 1_000_000_000)
    }

    private func commitRequiredSpace() {
        vm.updateRescueGoal(vm.rescueGoal, requiredSpace: parsedRequiredSpace)
    }

    private func syncRequiredSpaceText() {
        guard let required = vm.rescuePlan?.requiredSpace else {
            requiredSpaceText = ""
            return
        }
        requiredSpaceText = String(format: "%.1f", Double(required) / 1_000_000_000)
    }
}
