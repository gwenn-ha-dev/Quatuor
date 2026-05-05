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
        case .vocals: "Voix"
        case .drums:  "Batterie"
        case .bass:   "Basse"
        case .other:  "Autres"
        }
    }
}
