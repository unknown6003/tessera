import Foundation
#if canImport(MLXLMCommon)
import MLXLMCommon
import MLXLLM
#endif

// MARK: - On-device LLM (MLX)
//
// Runs a real ~4 GB quantized 7B model fully on-device via MLX (Apple Silicon).
// The model is downloaded once on explicit user request (it's large), then all
// inference is local — nothing leaves the Mac. When the model isn't downloaded the
// AI features simply fall back to their deterministic logic.

@MainActor
final class MLXModelManager: ObservableObject {
    static let shared = MLXModelManager()

    /// 4-bit 7B — strong instruction-following + JSON, ~4.3 GB on disk / ~5 GB RAM.
    let modelID = "mlx-community/Qwen2.5-7B-Instruct-4bit"
    let approxDownloadGB = 4.3

    enum State: Equatable {
        case notLoaded
        case loading(Double)     // 0…1 download/prepare progress
        case ready
        case unsupported(String) // framework/hardware unavailable
        case failed(String)
    }

    @Published private(set) var state: State

    #if canImport(MLXLMCommon)
    private var container: ModelContainer?
    private var loadTask: Task<Void, Never>?
    #endif

    private init() {
        #if canImport(MLXLMCommon)
        state = .notLoaded
        #else
        state = .unsupported("This build doesn't include the on-device model framework.")
        #endif
    }

    var isReady: Bool { state == .ready }

    var isBusy: Bool { if case .loading = state { return true }; return false }

    /// Begin downloading + loading the model (idempotent). Safe to call from the UI.
    func beginLoad() {
        #if canImport(MLXLMCommon)
        guard container == nil, loadTask == nil else { return }
        state = .loading(0)
        let id = modelID
        loadTask = Task { [weak self] in
            do {
                let c = try await loadModelContainer(id: id) { progress in
                    Task { @MainActor in
                        if case .loading = self?.state { self?.state = .loading(progress.fractionCompleted) }
                    }
                }
                self?.container = c
                self?.state = .ready
            } catch {
                self?.state = .failed(error.localizedDescription)
            }
            self?.loadTask = nil
        }
        #else
        state = .unsupported("This build doesn't include the on-device model framework.")
        #endif
    }

    /// Generate text for a one-shot prompt. Returns nil if the model isn't ready or
    /// inference fails — callers then fall back to deterministic logic. Does NOT
    /// trigger the (large) download; that's an explicit user action via `beginLoad`.
    func generate(instructions: String, prompt: String) async -> String? {
        #if canImport(MLXLMCommon)
        guard let container else { return nil }
        do {
            var params = GenerateParameters(temperature: 0.2)
            params.maxTokens = 700
            // A fresh session per call → stateless (no chat-history carryover).
            let session = ChatSession(container, instructions: instructions, generateParameters: params)
            return try await session.respond(to: prompt)
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}
