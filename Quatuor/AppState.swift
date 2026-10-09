import Foundation
import Observation

// MARK: - App State

/// Central state machine driving the UI. Each phase maps to a distinct screen.
@Observable
final class AppState {
    enum Phase {
        case idle
        case loading(fileName: String)
        case loaded(LoadedSource)
        case downloading(progress: Double)
        case processing(progress: Double)
        case done(SeparationResult)
        case failed(String)
    }

    var phase: Phase = .idle {
        didSet {
            if case .done(let result) = oldValue {
                result.cleanUp()
            }
        }
    }

    func reset() {
        phase = .idle
    }

    /// Reads a file's metadata and waveform, then shows it ready to separate.
    /// The drop zone, the open panel and `open -a Quatuor <file>` all come here.
    func open(_ url: URL) async {
        _ = url.startAccessingSecurityScopedResource()
        phase = .loading(fileName: url.lastPathComponent)
        do {
            let source = try await AudioDecoder.preview(url: url)
            phase = .loaded(source)
            // Launch key, for the README captures: `-open.separate YES` goes
            // straight to the stems, since nothing can click "Separate" for them.
            if UserDefaults.standard.bool(forKey: "open.separate") {
                await separate(source)
            }
        } catch {
            phase = .failed(String(localized: "Impossible de lire \(url.lastPathComponent) : \(error.localizedDescription)"))
        }
    }

    /// Downloads the model on first use, then separates `source` into its four stems.
    func separate(_ source: LoadedSource) async {
        do {
            if !ModelManager.shared.isModelDownloaded {
                phase = .downloading(progress: 0)
                try await ModelManager.shared.ensureModel { progress in
                    Task { @MainActor in
                        self.phase = .downloading(progress: progress)
                    }
                }
            }

            phase = .processing(progress: 0)
            let result = try await SeparationPipeline.shared.run(source: source) { progress in
                Task { @MainActor in
                    self.phase = .processing(progress: progress)
                }
            }
            phase = .done(result)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

// MARK: - Domain Models

/// Metadata and waveform preview for a loaded audio file, before separation.
struct LoadedSource {
    let url: URL
    let displayName: String
    let durationSeconds: Double
    let sampleRate: Double
    let channelCount: Int
    /// Downsampled peak amplitudes for waveform display, normalized to [0, 1].
    let waveformPeaks: [Float]
}

/// Output of the separation pipeline: the original source plus its isolated stems.
struct SeparationResult {
    struct Stem: Identifiable {
        let id = UUID()
        let kind: StemKind
        /// Temporary WAV file written by `SeparationPipeline` (16-bit PCM).
        let pcmFileURL: URL
        let waveformPeaks: [Float]
    }

    let source: LoadedSource
    let stems: [Stem]
    /// Temporary directory containing the WAV files. Caller is responsible for cleanup.
    let tempDirectory: URL

    func cleanUp() {
        try? FileManager.default.removeItem(at: tempDirectory)
    }
}

/// The four stem categories output by htdemucs.
/// Uses case-insensitive matching to handle variations in model output keys.
enum StemKind: String, CaseIterable {
    case vocals, drums, bass, other

    /// Case-insensitive lookup, e.g. "Vocals" → .vocals.
    nonisolated init?(fromModelKey key: String) {
        self.init(rawValue: key.lowercased())
    }

    var label: String {
        switch self {
        case .vocals: String(localized: "Voix")
        case .drums:  String(localized: "Batterie")
        case .bass:   String(localized: "Basse")
        case .other:  String(localized: "Autres")
        }
    }
}
