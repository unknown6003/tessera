import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var vm = ScanViewModel()

    var body: some View {
        // No GlassEffectContainer here. It merges every `.glassEffect` surface
        // within its spacing into ONE shared layer — which flattened the three
        // panels + the prominent Scan button into a single frosted sheet, exactly
        // the "glass on top of the sidebar" wash. Each panel now owns its glass.
        HStack(spacing: 18) {
            Sidebar(vm: vm)
                .frame(width: 252)

            centerArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            InspectorView(vm: vm)
                .frame(width: 296)
        }
        .padding(18)
        .frame(minWidth: 920, minHeight: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The whole app is a glass pane over the desktop. A STRONG full-window
        // frosted base (behind-window vibrancy, full strength) gives the window
        // clear, obviously-blurred bounds — the desktop reads as heavily frosted
        // behind it rather than showing through almost untouched. Panels then sit
        // on top with a light within-window material, frosting THIS base instead
        // of re-blurring the desktop, so the stacked-card effect stays gentle.
        .background(
            ZStack {
                DesktopGlass(material: GlassTuning.baseMaterial, blendingMode: .behindWindow,
                             emphasized: GlassTuning.baseEmphasized, cornerRadius: 18)
                Color.black.opacity(GlassTuning.baseTint)
            }
            .ignoresSafeArea()
        )
        .background(TransparentWindowConfigurator())
        .background(KeyboardShortcuts(vm: vm))
        .preferredColorScheme(.dark)
        .overlay {
            if vm.showFDAOnboarding {
                FullDiskAccessOnboarding(vm: vm)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.smooth(duration: 0.3), value: vm.showFDAOnboarding)
        .onAppear {
            vm.refreshFullDiskAccessStatus()
            DebugAutomation.runIfRequested(vm: vm)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Returning from System Settings after granting access auto-dismisses.
            vm.refreshFullDiskAccessStatus()
        }
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
        // Breadcrumb floats over the TOP edge only. Previously it was a
        // full-height `VStack { breadcrumb; Spacer() }` overlay, which sat above
        // the whole chart and swallowed every hover/click meant for the wedges.
        .overlay(alignment: .top) {
            if let current = vm.currentRoot {
                breadcrumb(for: current)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Glass card wrapper

    private func centeredCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(40)
            .frame(maxWidth: 460)
            // Behind-window glass so the empty / scanning / error cards refract the
            // desktop instead of refracting nothing over the transparent window.
            .desktopGlassPanel(cornerRadius: 28, shadowRadius: 34, shadowY: 18)
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
        .liquidGlassDepth(Capsule(), highlight: 0.9, shadowRadius: 16, shadowY: 8)
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
                .frame(width: 140, height: 140)

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
        ZStack {
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { ctx, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let maxR = min(size.width, size.height) / 2

                    // Expanding luminous rings refracting outward.
                    let count = 4
                    for i in 0..<count {
                        let phase = (t / 1.9 + Double(i) / Double(count)).truncatingRemainder(dividingBy: 1)
                        let radius = maxR * (0.16 + 0.84 * phase)
                        let opacity = (1 - phase) * (1 - phase) * 0.6
                        let hue = (0.58 + 0.12 * phase).truncatingRemainder(dividingBy: 1)
                        let rect = CGRect(
                            x: center.x - radius, y: center.y - radius,
                            width: radius * 2, height: radius * 2
                        )
                        ctx.stroke(
                            Path(ellipseIn: rect),
                            with: .color(Color(hue: hue, saturation: 0.7, brightness: 1.0).opacity(opacity)),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                    }

                    // A sweeping specular arc that orbits the core like a glint.
                    let glintAngle = Angle(degrees: (t * 90).truncatingRemainder(dividingBy: 360))
                    let glintR = maxR * 0.62
                    let arc = Path { p in
                        p.addArc(center: center, radius: glintR,
                                 startAngle: glintAngle,
                                 endAngle: glintAngle + .degrees(70),
                                 clockwise: false)
                    }
                    ctx.stroke(arc, with: .color(.white.opacity(0.55)),
                               style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
            }

            // Glass core hub that refracts the backdrop.
            Circle()
                .frame(width: 46, height: 46)
                .glassEffect(.regular.interactive(), in: Circle())
                .overlay(
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.tint)
                )
                .liquidGlassDepth(Circle(), highlight: 0.8, shadowRadius: 14, shadowY: 6)
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

// MARK: - Full Disk Access onboarding

/// First-launch overlay that asks for Full Disk Access once, up front, so the
/// app can read the whole disk instead of failing per-directory mid-scan. It
/// dims the window behind a glass card and auto-dismisses the moment access is
/// detected (the window re-checks on reactivation).
private struct FullDiskAccessOnboarding: View {
    @ObservedObject var vm: ScanViewModel

    private let steps: [(symbol: String, text: String)] = [
        ("1.circle.fill", "Click **Open System Settings** below."),
        ("2.circle.fill", "Find **Storage Optimizer** in the list and turn it on."),
        ("3.circle.fill", "Return here — scanning unlocks automatically."),
    ]

    var body: some View {
        ZStack {
            // Scrim that darkens and blurs the app behind the card.
            Rectangle()
                .fill(.black.opacity(0.45))
                .ignoresSafeArea()

            card
                .frame(maxWidth: 520)
                .padding(40)
        }
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        return VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.18))
                    .frame(width: 96, height: 96)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 46, weight: .light))
                    .foregroundStyle(.orange)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 10) {
                Text("Grant Full Disk Access")
                    .font(.title.weight(.semibold))
                Text("Storage Optimizer needs Full Disk Access to measure every folder on your Mac. Grant it once and you're set — no more per-folder prompts.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(steps, id: \.symbol) { step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: step.symbol)
                            .font(.title3)
                            .foregroundStyle(.tint)
                        Text(.init(step.text))
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 8)

            VStack(spacing: 10) {
                Button {
                    vm.openFullDiskAccessSettings()
                } label: {
                    Label("Open System Settings", systemImage: "gearshape.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)

                Button("Not Now") {
                    vm.dismissFDAOnboarding()
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
        }
        .padding(40)
        .glassEffect(.regular.interactive(), in: shape)
        .liquidGlassDepth(shape, shadowRadius: 40, shadowY: 22)
    }
}
