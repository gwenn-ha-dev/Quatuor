import Foundation
import DemucsMLX
import MLX

/// High-level wrapper around `DemucsSeparator` from demucs-mlx-swift.
///
/// - Lazily loads the htdemucs_ft model (fp16 safetensors) on first call.
///   Weights are auto-downloaded from HuggingFace (~336 MB).
/// - Bridges the closure-based `DemucsSeparator.separate()` API to Swift concurrency.
/// - Writes each stem to a temporary 16-bit WAV file for playback and MP3 export.
@MainActor
final class SeparationPipeline {
    static let shared = SeparationPipeline()

    enum Error: LocalizedError {
        case separatorInit(String)
        case inferenceFailed(String)
        case unknownStem(String)
        var errorDescription: String? {
            switch self {
            case .separatorInit(let m): String(localized: "Chargement du modèle htdemucs_ft échoué : \(m)")
            case .inferenceFailed(let m): String(localized: "Séparation échouée : \(m)")
            case .unknownStem(let n):  String(localized: "Stem inconnu retourné par le modèle : \(n)")
            }
        }
    }

    private var separator: DemucsSeparator?

    func run(
        source: LoadedSource,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> SeparationResult {
        let separator = try makeSeparator()
        let token = DemucsCancelToken()

        let previousCacheLimit = Memory.cacheLimit
        let available = Self.availableSystemMemory()
        if available > 0 {
            Memory.cacheLimit = Int(Double(available) * 0.70)
        }

        defer {
            self.separator = nil
            Memory.clearCache()
            Memory.cacheLimit = previousCacheLimit
        }

        let raw: DemucsSeparationResult = try await withCheckedThrowingContinuation { continuation in
            separator.separate(
                fileAt: source.url,
                cancelToken: token,
                progress: { p in
                    progress(Double(p.fraction))
                },
                completion: { result in
                    continuation.resume(with: result)
                }
            )
        }

        return try await Task.detached(priority: .userInitiated) {
            try Self.writeStems(raw: raw, source: source)
        }.value
    }

    private func makeSeparator() throws -> DemucsSeparator {
        if let existing = separator { return existing }
        do {
            let s = try DemucsSeparator(
                modelName: "htdemucs_ft",
                modelDirectory: ModelManager.shared.modelDirectory
            )
            separator = s
            return s
        } catch {
            throw Error.separatorInit(error.localizedDescription)
        }
    }

    /// Writes each separated stem to a temporary WAV file and computes waveform peaks.
    /// Runs off the main actor to avoid blocking the UI during file I/O.
    nonisolated private static func writeStems(
        raw: DemucsSeparationResult,
        source: LoadedSource
    ) throws -> SeparationResult {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("Quatuor-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var stems: [SeparationResult.Stem] = []
        for (name, audio) in raw.stems {
            guard let kind = StemKind(fromModelKey: name) else {
                throw Error.unknownStem(name)
            }
            let url = tempDir.appendingPathComponent("\(kind.rawValue).wav")
            try AudioIO.writeAudio(audio, to: url, format: .wav(bitDepth: .int16))
            let peaks = downsampledPeaks(from: audio, target: 800)
            stems.append(.init(kind: kind, pcmFileURL: url, waveformPeaks: peaks))
        }

        let ordered = StemKind.allCases.compactMap { kind in
            stems.first { $0.kind == kind }
        }
        return SeparationResult(source: source, stems: ordered, tempDirectory: tempDir)
    }

    /// Queries macOS Mach VM stats for free + inactive + purgeable memory.
    nonisolated private static func availableSystemMemory() -> UInt64 {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return ProcessInfo.processInfo.physicalMemory / 2
        }
        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS else {
            return ProcessInfo.processInfo.physicalMemory / 2
        }
        return (UInt64(stats.free_count) + UInt64(stats.inactive_count) + UInt64(stats.purgeable_count))
            * UInt64(pageSize)
    }

    nonisolated private static func downsampledPeaks(from audio: DemucsAudio, target: Int) -> [Float] {
        let frames = audio.frameCount
        let channels = audio.channels
        let samples = audio.channelMajorSamples
        guard frames > 0, target > 0 else { return [] }

        let bucketSize = max(1, frames / target)
        var peaks: [Float] = []
        peaks.reserveCapacity(target)

        var i = 0
        while i < frames {
            let end = min(i + bucketSize, frames)
            var maxAbs: Float = 0
            for c in 0..<channels {
                let base = c * frames
                for f in i..<end {
                    let s = abs(samples[base + f])
                    if s > maxAbs { maxAbs = s }
                }
            }
            peaks.append(maxAbs)
            i = end
        }
        if let m = peaks.max(), m > 0 {
            peaks = peaks.map { $0 / m }
        }
        return peaks
    }
}
