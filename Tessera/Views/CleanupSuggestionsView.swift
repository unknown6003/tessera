import SwiftUI
import AppKit

/// The Rescue task surface. It keeps the capacity target, measurement, and
/// ranked review list in one readable path.
struct CleanupSuggestionsView: View {
    @ObservedObject var vm: ScanViewModel
    /// Shows the in-page review button. The caller passes it only when the
    /// window's Cleanup List dock, which has its own filled review button, is
    /// not on screen, so the window never shows two filled review buttons.
    var onMoveToTrash: (() -> Void)? = nil

    @State private var expandedGroups = Set<String>()
    /// The group the user just opened. Only that one scrolls into sight, so
    /// returning to Rescue with open groups does not move the page.
    @State private var revealedGroup: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // With a plan, the header comes first and the saved case sits
            // under it as a banner (see planView).
            if vm.rescuePlan == nil, let saved = vm.savedRescueCase {
                savedCaseRow(saved, showsPath: true)
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
        .disabled(vm.isDeleting || vm.isScanning)
        .onAppear {
            if vm.rescuePlan != nil { vm.beginRescueReview() }
        }
    }

    @ViewBuilder
    private func planView(_ plan: RescuePlan) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            planHeader(plan)
            if let saved = vm.savedRescueCase {
                // The header already shows this path; show it again only if
                // the saved case is for a different source.
                savedCaseRow(saved, showsPath: saved.sourcePath != plan.sourcePath)
            }
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
                        // The one filled button only while the list is empty;
                        // after that the dock's review button is the primary.
                        prominent: vm.collector.isEmpty
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
                // File analysis is local; anonymous usage data is not, so this
                // line says only what is true.
                Text("File analysis runs on this Mac. Review the paths before anything moves.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            // The result for this folder leads; the drive-wide figures follow.
            if let summary = resultSummary {
                Text(summary)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            phaseBadge
        }
    }

    /// One line with what this scan found, in task order: what is safe to
    /// add now, then what needs a closer look.
    private var resultSummary: String? {
        guard let report = vm.cleanupReport, !report.isEmpty else { return nil }
        var parts: [String] = []
        if report.safeTotalBytes > 0 {
            parts.append("\(Theme.format(report.safeTotalBytes)) safe to review")
        }
        let review = report.reviewGroups.count
        if review > 0 {
            parts.append(review == 1 ? "1 group to check first" : "\(review) groups to check first")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var phaseBadge: some View {
        Label(vm.rescuePhase.title, systemImage: vm.rescuePhase.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(phaseColor)
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
                // Available and target share one size and one baseline.
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(primary.map(Theme.format) ?? "Unknown")
                            .font(.title2.weight(.semibold).monospacedDigit())
                        Text(primaryLabel(plan.measurement))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 16)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(targetTitle(plan))
                            .font(.title2.weight(.semibold).monospacedDigit())
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
                            .font(.title2.weight(.semibold).monospacedDigit())
                        Text(primaryLabel(plan.measurement))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(targetTitle(plan))
                            .font(.title2.weight(.semibold).monospacedDigit())
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
                    .accessibilityLabel(primaryLabel(plan.measurement))
                    .accessibilityValue(primary.map(Theme.format) ?? "Unknown")
                // The headline above already names the figure once, so this
                // caption carries only the goal.
                HStack {
                    Spacer()
                    Text("Goal: under \(capacityGoalPercent)% used")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) {
                    secondaryFreeMetric(plan.measurement)
                    metric("Logical", Theme.format(plan.measurement.logicalBytes))
                    metric("Physical", Theme.format(plan.measurement.physicalBytes))
                }
                .fixedSize(horizontal: true, vertical: false)

                VStack(alignment: .leading, spacing: 8) {
                    secondaryFreeMetric(plan.measurement)
                    metric("Logical", Theme.format(plan.measurement.logicalBytes))
                    metric("Physical", Theme.format(plan.measurement.physicalBytes))
                }
            }

            capacityGoalControl

            Text("Measured locally · \(plan.measurement.primarySource)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Definitions follow the figures and the goal control, so the
            // numbers and the one adjustable value come first.
            capacityNotes(plan)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Divider() }
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
        .padding(.vertical, 12)
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
                // The title names the state; the symbol is not read.
                .accessibilityHidden(true)

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
        .overlay(alignment: .bottom) { Divider() }
    }

    private func candidatesHeader(_ report: CleanupReport) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Suggested cleanup")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text(Theme.itemCount(report.recommendations.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Add only what you want to the Cleanup List. Tessera never removes a file from this screen.")
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
                        .tesseraButtonStyle(.flatProminent)
                        .controlSize(.small)
                        .disabled(actionDisabled)
                } else {
                    Button(actionTitle, action: action)
                        .tesseraButtonStyle(.flat)
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
                if value { expandedGroups.insert(group.id); revealedGroup = group.id }
                else { expandedGroups.remove(group.id) }
            }
        )

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                // A Tessera button, not the system disclosure arrow: it shows
                // the focus ring and scrolls into view on Tab.
                Button { expanded.wrappedValue.toggle() } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(expanded.wrappedValue ? 90 : 0))
                }
                .tesseraButtonStyle(.icon)
                .controlSize(.small)
                .accessibilityLabel(expanded.wrappedValue ? "Hide items in \(group.category.title)"
                                                          : "Show items in \(group.category.title)")

                Image(systemName: group.category.symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(color(for: group.risk))
                    .frame(width: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(group.category.title)
                        .font(.subheadline.weight(.semibold))
                    Text("\(group.nodes.count) item\(group.nodes.count == 1 ? "" : "s") · \(group.category.explanation)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { expanded.wrappedValue.toggle() }

                VStack(alignment: .trailing, spacing: 3) {
                    Text(Theme.format(group.totalBytes))
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                    riskTag(group.risk)
                }

                if group.risk != .protected {
                    let staged = vm.isGroupStaged(group)
                    Button(staged ? "Added" : "Add") {
                        vm.toggleCleanupGroup(group)
                    }
                    .tesseraButtonStyle(.flat)
                    .controlSize(.small)
                    .fixedSize()
                    .accessibilityLabel(staged ? "Remove \(group.category.title) from Cleanup List"
                                               : "Add \(group.category.title) to Cleanup List")
                } else {
                    Text("Owner handoff")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
            .padding(.vertical, 11)
            if expanded.wrappedValue {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(group.recommendations) { recommendation in
                        recommendationRow(recommendation)
                        if recommendation.id != group.recommendations.last?.id {
                            Divider().padding(.leading, 34)
                        }
                    }
                }
                .padding(.top, 4)
                // The items open at the bottom of the page; bring the first
                // rows into sight.
                .background { if revealedGroup == group.id { RevealOnAppear() } }
            }
        }
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) { Divider() }
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
                .tesseraButtonStyle(.interactive)
                .disabled(recommendation.risk == .protected || vm.isDeleting || vm.isScanning)
                .help(vm.isCollected(recommendation.node)
                      ? "Remove from the Cleanup List" : "Add to the Cleanup List")
                .accessibilityLabel(vm.isCollected(recommendation.node)
                                    ? "Remove \(recommendation.node.name) from Cleanup List"
                                    : "Add \(recommendation.node.name) to Cleanup List")

                // Row: name, size, one reason line and a risk tag. Path, owner,
                // side effect and proof sit in one disclosure.
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(recommendation.node.name)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(recommendation.risk.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(riskTint(recommendation.risk))
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .overlay(Capsule().strokeBorder(riskTint(recommendation.risk).opacity(0.5), lineWidth: 1))
                            .fixedSize()
                        Spacer(minLength: 8)
                        Text(Theme.format(recommendation.physicalBytes))
                            .font(.callout.monospacedDigit().weight(.semibold))
                            .fixedSize()
                    }

                    Text(recommendation.reason)
                        .font(.callout)
                        .foregroundStyle(Theme.mutedForeground)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(recommendation.reason)

                    DisclosureGroup("Details") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recommendation.path)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                            Text(sizeSummary(for: recommendation))
                                .font(.caption.monospacedDigit())
                            Text([recommendation.owner, recommendation.confidence.title,
                                  recommendation.action.title].joined(separator: " · "))
                                .font(.caption)
                            Text("May change: \(recommendation.sideEffect)")
                                .font(.caption)
                            ForEach(recommendation.proof, id: \.self) { item in
                                Text(item)
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                            }
                        }
                        .foregroundStyle(Theme.mutedForeground)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.caption)
                }
            }
        }
        .padding(.vertical, 6)
        .contextMenu {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([recommendation.node.url])
            } label: {
                Label("Reveal in Finder", systemImage: "magnifyingglass")
            }
        }
    }

    private func riskTint(_ risk: CleanupRisk) -> Color {
        switch risk {
        case .safe: return Theme.electricBlue
        case .review: return Theme.crossVolumeColor
        case .protected: return Theme.danger
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

            Text(verification.recoveryNote)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let requested = verification.requestedBytes {
                Text("Requested usable space: \(Theme.format(requested))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .overlay(alignment: .bottom) { Divider() }
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
                    Text("Cleanup List ready")
                        .font(.subheadline.weight(.semibold))
                    Text("\(vm.collector.count) item\(vm.collector.count == 1 ? "" : "s") · \(Theme.format(vm.collectorTotalSize))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("Review the exact paths before you confirm.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                moveToTrash()
            } label: {
                Label("Review Cleanup List…", systemImage: "checklist")
            }
            .tesseraButtonStyle(.flatProminent)
            .controlSize(.regular)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Divider() }
    }

    /// The headline figure is `primaryBytes`: macOS "available for important
    /// usage" when known (it counts space macOS can reclaim from caches and
    /// other purgeable files), else plain free space. The label follows the
    /// value actually shown.
    private func primaryLabel(_ measurement: RescueMeasurement) -> String {
        measurement.availableBytes != nil ? "Available for use" : "Free now"
    }

    @ViewBuilder
    private func capacityNotes(_ plan: RescuePlan) -> some View {
        let notes = [
            plan.measurement.availableBytes != nil
                ? "Available for use counts space macOS can reclaim by removing caches and other purgeable files. Free now is the space macOS reports as free at this moment."
                : nil,
            // True for a volume root and for a folder alike, so it needs no
            // path test. (`volumePath` is the selected source path, not the
            // mount point, so comparing it with `sourcePath` cannot tell them
            // apart.)
            "Capacity figures cover the whole drive that holds this source. Logical and physical totals cover only the scanned source.",
        ].compactMap { $0 }
        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(notes, id: \.self) { note in
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Plain free space, shown beside the headline only when the headline is
    /// the larger "available for use" figure.
    @ViewBuilder
    private func secondaryFreeMetric(_ measurement: RescueMeasurement) -> some View {
        if measurement.availableBytes != nil {
            metric("Free now", measurement.freeBytes.map(Theme.format) ?? "Unknown")
        }
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

    private func riskTag(_ risk: CleanupRisk) -> some View {
        Text(risk.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color(for: risk))
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
            ? "more space needed to reach \(capacityGoalPercent)% used"
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
