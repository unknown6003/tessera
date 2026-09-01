import SwiftUI
import AppKit

/// The Rescue task surface. It keeps the capacity target, measurement, and
/// ranked review list in one readable path.
struct CleanupSuggestionsView: View {
    @ObservedObject var vm: ScanViewModel
    var onMoveToTrash: (() -> Void)? = nil

    @State private var expandedGroups = Set<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let saved = vm.savedRescueCase {
                savedCaseRow(saved)
            }

            if let plan = vm.rescuePlan {
                planView(plan)
                if let onMoveToTrash, !vm.collector.isEmpty {
                    reviewFooter(onMoveToTrash)
                }
            } else {
                emptyPlan
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if vm.rescuePlan != nil { vm.beginRescueReview() }
        }
    }

    @ViewBuilder
    private func planView(_ plan: RescuePlan) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            planHeader(plan)
            measurementCard(plan)

            if let verification = vm.rescueVerification {
                verificationCard(verification)
            } else if let error = vm.lastRescueError {
                resultErrorCard(error)
            }

            coverageCard(plan.coverage)

            if let report = vm.cleanupReport, !report.isEmpty {
                candidatesHeader(report)

                if !report.safeGroups.isEmpty {
                    candidateSection(
                        title: "Safe to review",
                        subtitle: "Known generated files. They can be rebuilt, but the next build may take longer.",
                        groups: report.safeGroups,
                        action: {
                            vm.stageSafeCleanup()
                        },
                        actionTitle: vm.safeGroupsAllStaged
                            ? "Added to review"
                            : "Add all safe · \(Theme.format(report.safeTotalBytes))",
                        actionDisabled: vm.safeGroupsAllStaged,
                        prominent: true
                    )
                }

                if !report.reviewGroups.isEmpty {
                    candidateSection(
                        title: "Review first",
                        subtitle: "These may be useful, shared, active, or tied to an owner app. Nothing is added automatically.",
                        groups: report.reviewGroups,
                        action: nil,
                        actionTitle: nil,
                        actionDisabled: false,
                        prominent: false
                    )
                }

                if !report.protectedGroups.isEmpty {
                    candidateSection(
                        title: "Protected",
                        subtitle: "Tessera will not stage these. Use the owner app or keep them in place.",
                        groups: report.protectedGroups,
                        action: nil,
                        actionTitle: nil,
                        actionDisabled: false,
                        prominent: false
                    )
                }
            } else {
                emptyCandidates
            }
        }
    }

    private func planHeader(_ plan: RescuePlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Rescue space")
                    .font(.title2.weight(.semibold))
                Text(plan.sourcePath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text("Everything stays on this Mac. Review the paths before anything moves.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            phaseBadge
        }
    }

    private var phaseBadge: some View {
        Label(vm.rescuePhase.title, systemImage: vm.rescuePhase.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(phaseColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(phaseColor.opacity(0.12), in: Capsule())
    }

    private var phaseColor: Color {
        switch vm.rescuePhase {
        case .result: return Theme.electricBlue
        case .confirmingTrash, .moving, .verifying: return .orange
        default: return .secondary
        }
    }

    private func measurementCard(_ plan: RescuePlan) -> some View {
        let primary = plan.measurement.primaryBytes
        let fraction = capacityFraction(plan.measurement)

        return VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(primary.map(Theme.format) ?? "Unknown")
                            .font(.system(.largeTitle, design: .rounded).weight(.semibold).monospacedDigit())
                        Text("available now")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 16)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(targetTitle(plan))
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .foregroundStyle(targetColor(plan))
                        Text(targetLabel(plan))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(primary.map(Theme.format) ?? "Unknown")
                            .font(.system(.largeTitle, design: .rounded).weight(.semibold).monospacedDigit())
                        Text("available now")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(targetTitle(plan))
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .foregroundStyle(targetColor(plan))
                        Text(targetLabel(plan))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let fraction {
                ProgressView(value: fraction)
                    .tint(targetColor(plan))
                    .accessibilityLabel("Free capacity")
                    .accessibilityValue(primary.map(Theme.format) ?? "Unknown")
                HStack {
                    Text("Free capacity")
                    Spacer()
                    Text("Goal: \(100 - capacityGoalPercent)% free")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) {
                    metric("Free", plan.measurement.freeBytes.map(Theme.format) ?? "Unknown")
                    metric("Logical", Theme.format(plan.measurement.logicalBytes))
                    metric("Physical", Theme.format(plan.measurement.physicalBytes))
                }
                .fixedSize(horizontal: true, vertical: false)

                VStack(alignment: .leading, spacing: 8) {
                    metric("Free", plan.measurement.freeBytes.map(Theme.format) ?? "Unknown")
                    metric("Logical", Theme.format(plan.measurement.logicalBytes))
                    metric("Physical", Theme.format(plan.measurement.physicalBytes))
                }
            }

            capacityGoalControl

            Text("Measured locally · \(plan.measurement.primarySource)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Theme.borderStrong, lineWidth: 1))
    }

    private var capacityGoalControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Capacity goal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Keep used space under")
                        .font(.subheadline.weight(.medium))
                    Text("Adjust with the stepper.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Stepper(value: Binding(
                    get: { vm.rescueCapacityGoal },
                    set: { vm.updateRescueCapacityGoal($0) }
                ), in: RescuePlan.capacityGoalRange, step: 0.05) {
                    Text("\(capacityGoalPercent)%")
                        .font(.headline.monospacedDigit())
                        .frame(minWidth: 42, alignment: .trailing)
                }
                .controlSize(.small)
                .accessibilityLabel("Used space limit")
                .accessibilityValue("\(capacityGoalPercent) percent")
            }
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func coverageCard(_ coverage: RescueCoverage) -> some View {
        let color: Color = coverage.state == .blocked
            ? Theme.danger
            : (coverage.state == .complete ? Theme.electricBlue : .orange)

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: coverage.state == .blocked
                  ? "lock.fill"
                  : (coverage.state == .complete ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"))
                .font(.title3)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 4) {
                Text(coverage.title)
                    .font(.headline.weight(.semibold))
                if coverage.notes.isEmpty {
                    Text("The scan reported no gaps.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(coverage.notes, id: \.self) { note in
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(color.opacity(0.35), lineWidth: 1))
    }

    private func candidatesHeader(_ report: CleanupReport) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Suggested cleanup")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(report.recommendations.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Add only what you want to the review queue. Tessera never removes a file from this screen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func candidateSection(
        title: String,
        subtitle: String,
        groups: [CleanupReport.Group],
        action: (() -> Void)?,
        actionTitle: String?,
        actionDisabled: Bool,
        prominent: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let action, let actionTitle {
                if prominent {
                    Button(actionTitle, action: action)
                        .buttonStyle(.flatProminent)
                        .controlSize(.small)
                        .disabled(actionDisabled)
                } else {
                    Button(actionTitle, action: action)
                        .buttonStyle(.flat)
                        .controlSize(.small)
                        .disabled(actionDisabled)
                }
            }

            ForEach(groups) { group in
                groupRow(group)
            }
        }
    }

    @ViewBuilder
    private func groupRow(_ group: CleanupReport.Group) -> some View {
        let expanded = Binding(
            get: { expandedGroups.contains(group.id) },
            set: { value in
                if value { expandedGroups.insert(group.id) }
                else { expandedGroups.remove(group.id) }
            }
        )

        DisclosureGroup(isExpanded: expanded) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(group.recommendations) { recommendation in
                    recommendationRow(recommendation)
                    if recommendation.id != group.recommendations.last?.id {
                        Divider().padding(.leading, 34)
                    }
                }
            }
            .padding(.top, 4)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: group.category.symbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(color(for: group.risk))
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.category.title)
                            .font(.subheadline.weight(.semibold))
                        Text("\(group.nodes.count) item\(group.nodes.count == 1 ? "" : "s") · \(group.category.explanation)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(Theme.format(group.totalBytes))
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                        riskTag(group.risk)
                    }
                }

                HStack(spacing: 8) {
                    if group.risk != .protected {
                        Button(vm.isGroupStaged(group) ? "Added" : "Add") {
                            vm.toggleCleanupGroup(group)
                        }
                        .buttonStyle(.flat)
                        .controlSize(.small)
                    } else {
                        Text("Owner handoff")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .tint(.secondary)
        .padding(.horizontal, 12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Theme.border, lineWidth: 1))
    }

    private func recommendationRow(_ recommendation: CleanupRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 10) {
                Button {
                    if vm.isCollected(recommendation.node) {
                        vm.removeFromCollector(recommendation.node)
                    } else {
                        vm.addToCollector(recommendation.node)
                    }
                } label: {
                    Image(systemName: vm.isCollected(recommendation.node)
                          ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(vm.isCollected(recommendation.node)
                                         ? Theme.electricBlue : Theme.mutedForeground)
                }
                .buttonStyle(.interactive)
                .help(vm.isCollected(recommendation.node)
                      ? "Remove from the review queue" : "Add to the review queue")
                .accessibilityLabel(vm.isCollected(recommendation.node)
                                    ? "Remove from review queue" : "Add to review queue")

                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.node.name)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(Theme.format(recommendation.physicalBytes))
                        .font(.subheadline.monospacedDigit().weight(.semibold))

                    Text(recommendation.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)

                    Text(sizeSummary(for: recommendation))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Text(recommendation.reason)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text([recommendation.owner, recommendation.confidence.title,
                          recommendation.action.title].joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("May change: \(recommendation.sideEffect)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    DisclosureGroup("Proof") {
                        ForEach(recommendation.proof, id: \.self) { item in
                            Text(item)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.vertical, 10)
        .contextMenu {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([recommendation.node.url])
            } label: {
                Label("Reveal in Finder", systemImage: "magnifyingglass")
            }
        }
    }

    private func sizeSummary(for recommendation: CleanupRecommendation) -> String {
        var summary = "\(Theme.format(recommendation.physicalBytes)) allocated"
        if let logical = recommendation.logicalBytes {
            summary += " · \(Theme.format(logical)) logical"
        }
        return summary
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

            Text("Trash still uses disk space until you empty it.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let requested = verification.requestedBytes {
                Text("Requested usable space: \(Theme.format(requested))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            pathDisclosure(title: "Moved paths", paths: verification.movedPaths)
            pathDisclosure(title: "Held paths", paths: verification.heldPaths)
            pathDisclosure(title: "Paths that did not match", paths: verification.measurementMismatchPaths)
            pathDisclosure(title: "Failed paths", paths: verification.failedPaths)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(color.opacity(0.35), lineWidth: 1))
    }

    @ViewBuilder
    private func verificationMetrics(_ verification: RescueVerification) -> some View {
        metric("Moved to Trash", Theme.format(verification.movedBytes))
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
                        .lineLimit(2)
                        .truncationMode(.middle)
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
            .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func savedCaseRow(_ saved: SavedRescueCase) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saved rescue case")
                        .font(.headline.weight(.semibold))
                    Text("Kept on this Mac. A fresh scan is required before staging anything.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(saved.sourcePath)
                .font(.caption.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("Reopen and rescan") { vm.reopenSavedRescueCase() }
                    .buttonStyle(.flatProminent)
                    .controlSize(.small)
                    .disabled(vm.isScanning)
                Button("Forget") { vm.discardSavedRescueCase() }
                    .buttonStyle(.flat)
                    .controlSize(.small)
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
                        .buttonStyle(.flat)
                        .controlSize(.small)
                }
                Text("Nothing is staged until you choose this action.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Theme.electricBlue.opacity(0.35), lineWidth: 1))
    }

    private var emptyPlan: some View {
        VStack(alignment: .leading, spacing: 10) {
            FeatureSectionLabel("Rescue space")
            if vm.isScanning {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Building the rescue plan…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let error = vm.lastRescueError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Label("Scan a source to build a plan.", systemImage: "magnifyingglass")
                    .font(.subheadline)
                Text("Tessera reads local storage only. It does not move or upload files while it measures.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyCandidates: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nothing to suggest yet")
                .font(.headline.weight(.semibold))
            Text("The scan found no known cleanup candidates. The coverage and measurement above still describe the current volume.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func reviewFooter(_ moveToTrash: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checklist")
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 32, height: 32)
                    .background(Theme.selectionTint, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Review queue ready")
                        .font(.subheadline.weight(.semibold))
                    Text("\(vm.collector.count) item\(vm.collector.count == 1 ? "" : "s") · \(Theme.format(vm.collectorTotalSize))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("A confirmation comes next. Finder Trash is recoverable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                moveToTrash()
            } label: {
                Label("Move to Trash", systemImage: "trash.fill")
            }
            .buttonStyle(.flatProminent)
            .controlSize(.regular)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Theme.electricBlue.opacity(0.35), lineWidth: 1))
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

    private func riskTag(_ risk: CleanupRisk) -> some View {
        Text(risk.title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color(for: risk))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color(for: risk).opacity(0.12), in: Capsule())
    }

    private func color(for risk: CleanupRisk) -> Color {
        switch risk {
        case .safe: return Theme.electricBlue
        case .review: return .orange
        case .protected: return .secondary
        }
    }

    private func targetTitle(_ plan: RescuePlan) -> String {
        guard let target = plan.targetSpace, let available = plan.measurement.primaryBytes else {
            return "—"
        }
        return target > available ? Theme.format(target - available) : "On target"
    }

    private func targetLabel(_ plan: RescuePlan) -> String {
        guard plan.targetSpace != nil else { return "capacity target unavailable" }
        guard let target = plan.targetSpace, let available = plan.measurement.primaryBytes else {
            return "capacity target unavailable"
        }
        return target > available
            ? "more free space to reach \(capacityGoalPercent)% used"
            : "\(capacityGoalPercent)% used limit met"
    }

    private func targetColor(_ plan: RescuePlan) -> Color {
        guard let target = plan.targetSpace, let available = plan.measurement.primaryBytes else {
            return .secondary
        }
        return target > available ? .orange : Theme.electricBlue
    }

    private func capacityFraction(_ measurement: RescueMeasurement) -> Double? {
        guard let total = measurement.totalBytes, total > 0,
              let primary = measurement.primaryBytes else { return nil }
        return min(1, max(0, Double(primary) / Double(total)))
    }

    private var capacityGoalPercent: Int {
        Int((vm.rescueCapacityGoal * 100).rounded())
    }
}
