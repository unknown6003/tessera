import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var vm = ScanViewModel()

    var body: some View {
        HStack(spacing: 16) {
            Sidebar(vm: vm)
                .frame(width: 250)

            centerArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            InspectorView(vm: vm)
                .frame(width: 290)
        }
        .padding(16)
        .frame(minWidth: 920, minHeight: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Rectangle().fill(Theme.backgroundGradient).ignoresSafeArea())
        .background(KeyboardShortcuts(vm: vm))
        .onAppear { DebugAutomation.runIfRequested(vm: vm) }
    }

    // MARK: - Center area

    @ViewBuilder
    private var centerArea: some View {
        ZStack {
            if vm.needsFullDiskAccess {
                centeredCard { fullDiskAccessContent }
            } else if let error = vm.errorMessage {
                centeredCard { errorContent(error) }
            } else if vm.rootNode == nil && vm.isScanning {
                centeredCard { ScanningView(vm: vm) }
            } else if vm.rootNode == nil {
                centeredCard { emptyContent }
            } else {
                chartContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.smooth(duration: 0.35), value: vm.rootNode?.id)
        .animation(.smooth(duration: 0.25), value: vm.isScanning)
    }

    // MARK: - Chart + breadcrumb

    @ViewBuilder
    private var chartContent: some View {
        ZStack {
            SunburstChart(
                root: vm.currentRoot,
                hoveredNode: vm.hoveredNode,
                selectedNode: vm.selectedNode,
                onHover: { vm.hoveredNode = $0 },
                onSelect: { vm.selectedNode = $0 },
                onZoomIn: { vm.zoomIn(to: $0) },
                onZoomOut: { vm.zoomOut() },
                onAddToCollector: { vm.addToCollector($0) },
                onRevealInFinder: { node in
                    NSWorkspace.shared.activateFileViewerSelecting([node.url])
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let current = vm.currentRoot {
                VStack {
                    breadcrumb(for: current)
                        .padding(.top, 4)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Glass card wrapper

    private func centeredCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(36)
            .frame(maxWidth: 460)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.18), radius: 26, y: 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }

    // MARK: - Empty state

    private var emptyContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "internaldrive")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                Text("Ready to Explore")
                    .font(.title2.weight(.semibold))
                Text("Select a volume and press Scan.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Full Disk Access

    private var fullDiskAccessContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.orange)
            VStack(spacing: 8) {
                Text("Full Disk Access Required")
                    .font(.title2.weight(.semibold))
                Text("Grant Full Disk Access in System Settings, then scan again.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Open System Settings") {
                vm.openFullDiskAccessSettings()
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Error

    private func errorContent(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.red)
            VStack(spacing: 8) {
                Text("Scan Failed")
                    .font(.title2.weight(.semibold))
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Dismiss") {
                vm.errorMessage = nil
            }
            .buttonStyle(.glass)
            .controlSize(.large)
        }
    }

    // MARK: - Breadcrumb

    private func breadcrumb(for node: FileNode) -> some View {
        let ancestors = ancestorChain(of: node)
        return GlassEffectContainer {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button {
                        vm.zoomToRoot()
                    } label: {
                        Image(systemName: "house.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .help("Zoom to root")

                    ForEach(ancestors) { ancestor in
                        chevron
                        Button(ancestor.name) {
                            vm.currentRoot = ancestor
                            vm.selectedNode = ancestor
                            vm.hoveredNode = nil
                        }
                        .buttonStyle(.plain)
                        .font(.subheadline)
                        .lineLimit(1)
                    }

                    if !ancestors.isEmpty { chevron }

                    Text(node.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(Theme.format(node.size))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
            }
            .frame(maxWidth: 560)
            .fixedSize(horizontal: true, vertical: false)
        }
        .glassEffect(.regular.interactive(), in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }

    private func ancestorChain(of node: FileNode) -> [FileNode] {
        var chain: [FileNode] = []
        var cursor = node.parent
        while let c = cursor {
            chain.insert(c, at: 0)
            cursor = c.parent
        }
        return chain
    }
}

// MARK: - Scanning state

private struct ScanningView: View {
    @ObservedObject var vm: ScanViewModel

    var body: some View {
        VStack(spacing: 24) {
            PulsingRings()
                .frame(width: 132, height: 132)

            VStack(spacing: 6) {
                Text("Scanning…")
                    .font(.title2.weight(.semibold))
                if let fraction = vm.progress.fraction {
                    Text("\(Int(fraction * 100))%")
                        .font(.system(.largeTitle, design: .rounded).weight(.medium).monospacedDigit())
                        .contentTransition(.numericText())
                        .animation(.smooth, value: fraction)
                }
            }

            HStack(spacing: 28) {
                counter(value: "\(vm.progress.filesScanned)", label: "Files")
                counter(value: Theme.format(vm.progress.bytesFound), label: "Found")
            }

            Text(vm.progress.currentPath)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 360)

            Button(role: .cancel) {
                vm.cancelScan()
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .buttonStyle(.glass)
            .controlSize(.large)
        }
    }

    private func counter(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .contentTransition(.numericText())
                .animation(.smooth, value: value)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Pulsing concentric rings

private struct PulsingRings: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxR = min(size.width, size.height) / 2
                let count = 3
                for i in 0..<count {
                    let phase = (t / 1.6 + Double(i) / Double(count)).truncatingRemainder(dividingBy: 1)
                    let radius = maxR * (0.2 + 0.8 * phase)
                    let opacity = (1 - phase) * 0.55
                    let rect = CGRect(
                        x: center.x - radius, y: center.y - radius,
                        width: radius * 2, height: radius * 2
                    )
                    ctx.stroke(
                        Path(ellipseIn: rect),
                        with: .color(Color.accentColor.opacity(opacity)),
                        lineWidth: 3
                    )
                }
                // Steady core
                let coreR = maxR * 0.16
                let coreRect = CGRect(
                    x: center.x - coreR, y: center.y - coreR,
                    width: coreR * 2, height: coreR * 2
                )
                ctx.fill(
                    Path(ellipseIn: coreRect),
                    with: .color(Color.accentColor.opacity(0.85))
                )
            }
        }
    }
}

// MARK: - Keyboard shortcuts (hidden helper buttons)

private struct KeyboardShortcuts: View {
    @ObservedObject var vm: ScanViewModel

    var body: some View {
        ZStack {
            Button("Zoom Out") { vm.zoomOut() }
                .keyboardShortcut(.upArrow, modifiers: .command)
            Button("Clear Selection") { vm.selectedNode = nil }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }
}
