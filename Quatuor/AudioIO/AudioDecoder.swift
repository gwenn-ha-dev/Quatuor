import Foundation
import AVFoundation

/// Decodes audio files into the format expected by the separation pipeline
/// (float32, stereo, 44.1 kHz) and computes downsampled waveform peaks for display.
enum AudioDecoder {
    enum Error: LocalizedError {
        case unreadable(URL)
        var errorDescription: String? {
            switch self {
            case .unreadable(let url): String(localized: "Impossible de lire \(url.lastPathComponent)")
            }
        }
    }

    /// Computes waveform peaks and metadata by streaming the file in small chunks,
    /// without loading the entire PCM buffer into memory.
    static func preview(url: URL) async throws -> LoadedSource {
        return try await Task.detached(priority: .userInitiated) {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let totalFrames = Int(file.length)
            let sampleRate = format.sampleRate
            let channels = Int(format.channelCount)
            guard totalFrames > 0 else { throw Error.unreadable(url) }

            let targetPeaks = 2_000
            let bucketSize = max(1, totalFrames / targetPeaks)
            let chunkFrames: AVAudioFrameCount = 16384
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) else {
                throw Error.unreadable(url)
            }

            var peaks: [Float] = []
            peaks.reserveCapacity(targetPeaks)
            var bucketMax: Float = 0
            var bucketCount = 0

            while file.framePosition < file.length {
                // AVAudioFile.length is an estimate for compressed formats (MP3, AAC).
                // Reading the final partial chunk can fail — treat as EOF.
                do {
                    try file.read(into: buffer)
                } catch {
                    break
                }
                let frames = Int(buffer.frameLength)
                guard frames > 0, let channelData = buffer.floatChannelData else { break }

                for f in 0..<frames {
                    var sampleMax: Float = 0
                    for ch in 0..<min(channels, Int(format.channelCount)) {
                        let s = abs(channelData[ch][f])
                        if s > sampleMax { sampleMax = s }
                    }
                    if sampleMax > bucketMax { bucketMax = sampleMax }
                    bucketCount += 1

                    if bucketCount >= bucketSize {
                        peaks.append(bucketMax)
                        bucketMax = 0
                        bucketCount = 0
                    }
                }
            }
            if bucketCount > 0 { peaks.append(bucketMax) }

            if let m = peaks.max(), m > 0 {
                peaks = peaks.map { $0 / m }
            }

            return LoadedSource(
                url: url,
                displayName: url.lastPathComponent,
                durationSeconds: Double(totalFrames) / sampleRate,
                sampleRate: sampleRate,
                channelCount: channels,
                waveformPeaks: peaks
            )
        }.value
    }
}
