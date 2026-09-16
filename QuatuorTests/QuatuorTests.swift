import AVFoundation
import Foundation
import Testing

@testable import Quatuor

// MARK: - Fixtures

/// Writes `seconds` of a 440 Hz sine to a temporary WAV file and returns its URL.
private func makeSineWAV(
    seconds: Double = 1.0,
    sampleRate: Double = 44_100,
    channels: AVAudioChannelCount = 2,
    amplitude: Float = 0.5
) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("quatuor-test-\(UUID().uuidString).wav")
    let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
    let file = try AVAudioFile(forWriting: url, settings: format.settings)

    let frames = AVAudioFrameCount(seconds * sampleRate)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
    buffer.frameLength = frames
    for channel in 0..<Int(channels) {
        let samples = buffer.floatChannelData![channel]
        for frame in 0..<Int(frames) {
            samples[frame] = amplitude * sinf(2 * .pi * 440 * Float(frame) / Float(sampleRate))
        }
    }
    try file.write(from: buffer)
    return url
}

// MARK: - Stem kinds

@MainActor
@Suite("Stem kinds")
struct StemKindTests {

    /// htdemucs returns its keys in whatever case it pleases; the mapping absorbs that.
    @Test func matchesModelKeysWhateverTheirCase() {
        #expect(StemKind(fromModelKey: "vocals") == .vocals)
        #expect(StemKind(fromModelKey: "Drums") == .drums)
        #expect(StemKind(fromModelKey: "BASS") == .bass)
        #expect(StemKind(fromModelKey: "Other") == .other)
    }

    @Test func rejectsAKeyThatIsNotAStem() {
        #expect(StemKind(fromModelKey: "piano") == nil)
        #expect(StemKind(fromModelKey: "") == nil)
    }

    @Test func coversTheFourStemsInAStableOrder() {
        #expect(StemKind.allCases == [.vocals, .drums, .bass, .other])
    }
}

// MARK: - Decoding

@MainActor
@Suite("Audio decoding")
struct AudioDecoderTests {

    @Test func readsMetadataFromTheFile() async throws {
        let url = try makeSineWAV(seconds: 1.0)
        defer { try? FileManager.default.removeItem(at: url) }

        let source = try await AudioDecoder.preview(url: url)

        #expect(source.sampleRate == 44_100)
        #expect(source.channelCount == 2)
        #expect(abs(source.durationSeconds - 1.0) < 0.01)
        #expect(source.displayName == url.lastPathComponent)
    }

    /// The waveform view draws peaks directly, so they must land in [0, 1] with
    /// the loudest one at exactly 1 — otherwise a quiet file renders as a flat line.
    @Test func normalisesThePeaksItComputes() async throws {
        let url = try makeSineWAV(seconds: 1.0, amplitude: 0.1)
        defer { try? FileManager.default.removeItem(at: url) }

        let peaks = try await AudioDecoder.preview(url: url).waveformPeaks

        #expect(!peaks.isEmpty)
        #expect(peaks.allSatisfy { $0 >= 0 && $0 <= 1 })
        #expect(abs((peaks.max() ?? 0) - 1) < 0.0001)
    }

    /// ~2 000 peaks whatever the duration: the view samples a fixed width.
    @Test func producesAStableNumberOfPeaks() async throws {
        let short = try makeSineWAV(seconds: 0.5)
        let long = try makeSineWAV(seconds: 4.0)
        defer {
            try? FileManager.default.removeItem(at: short)
            try? FileManager.default.removeItem(at: long)
        }

        let shortPeaks = try await AudioDecoder.preview(url: short).waveformPeaks.count
        let longPeaks = try await AudioDecoder.preview(url: long).waveformPeaks.count

        #expect((1_900...2_100).contains(shortPeaks))
        #expect((1_900...2_100).contains(longPeaks))
    }

    @Test func refusesAFileThatIsNotAudio() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("quatuor-test-\(UUID().uuidString).wav")
        try Data("this is not a WAV".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        await #expect(throws: (any Error).self) {
            _ = try await AudioDecoder.preview(url: url)
        }
    }
}

// MARK: - MP3 export

@MainActor
@Suite("MP3 encoding")
struct MP3EncoderTests {

    @Test func writesAnMP3ThatPlaysBack() async throws {
        let wav = try makeSineWAV(seconds: 0.5)
        let mp3 = FileManager.default.temporaryDirectory
            .appendingPathComponent("quatuor-test-\(UUID().uuidString).mp3")
        defer {
            try? FileManager.default.removeItem(at: wav)
            try? FileManager.default.removeItem(at: mp3)
        }

        try await MP3Encoder.shared.encode(pcmFileURL: wav, to: mp3)

        let size = try FileManager.default.attributesOfItem(atPath: mp3.path)[.size] as? Int ?? 0
        #expect(size > 0)

        // Reading it back is the real check: libmp3lame was configured and flushed.
        let encoded = try AVAudioFile(forReading: mp3)
        let duration = Double(encoded.length) / encoded.processingFormat.sampleRate
        #expect(abs(duration - 0.5) < 0.1)
    }
}

// MARK: - Result lifecycle

@MainActor
@Suite("Result lifecycle")
struct SeparationResultTests {

    /// Each separation leaves four WAVs in a temporary directory. Leaving the
    /// `.done` phase must delete them, or a long session fills the disk.
    @Test func leavingTheDonePhaseDeletesTheTemporaryFiles() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("quatuor-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let stemFile = tempDir.appendingPathComponent("vocals.wav")
        try Data("pcm".utf8).write(to: stemFile)

        let source = LoadedSource(
            url: tempDir.appendingPathComponent("source.mp3"),
            displayName: "source.mp3",
            durationSeconds: 1,
            sampleRate: 44_100,
            channelCount: 2,
            waveformPeaks: [0, 1]
        )
        let result = SeparationResult(
            source: source,
            stems: [.init(kind: .vocals, pcmFileURL: stemFile, waveformPeaks: [0, 1])],
            tempDirectory: tempDir
        )

        let state = AppState()
        state.phase = .done(result)
        #expect(FileManager.default.fileExists(atPath: tempDir.path))

        state.reset()
        #expect(!FileManager.default.fileExists(atPath: tempDir.path))
    }
}
