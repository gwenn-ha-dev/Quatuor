import Foundation
import AppKit
import AVFoundation

/// Encodes PCM audio to MP3 using libmp3lame (VBR V2, ~190 kbps).
///
/// Requires `libmp3lame.a` to be compiled and linked. See `Scripts/build_lame.sh`
/// and the bridging header at `Stem/AudioIO/lame-bridge.h`.
@MainActor
final class MP3Encoder {
    static let shared = MP3Encoder()

    enum Error: LocalizedError {
        case lameNotLinked
        case userCancelled
        case writeFailed(String)
        var errorDescription: String? {
            switch self {
            case .lameNotLinked:    "libmp3lame n'est pas encore liée — exécute Scripts/build_lame.sh puis ajoute la static lib au target."
            case .userCancelled:    "Export annulé"
            case .writeFailed(let m): "Écriture MP3 échouée : \(m)"
            }
        }
    }

    /// Presents a save panel and encodes the WAV stem to MP3 at the chosen location.
    func export(pcmFileURL: URL, suggestedName: String) async throws {
        let destination = try await pickSaveDestination(suggestedName: suggestedName)
        try await encode(pcmFileURL: pcmFileURL, to: destination)
    }

    /// Exports all stems as MP3 into a user-chosen folder.
    func exportAll(stems: [SeparationResult.Stem], baseName: String) async throws {
        let folder = try await pickFolder()
        for stem in stems {
            let name = "\(baseName) - \(stem.kind.label).mp3"
            let destination = folder.appendingPathComponent(name)
            try await encode(pcmFileURL: stem.pcmFileURL, to: destination)
        }
    }

    @MainActor
    private func pickSaveDestination(suggestedName: String) async throws -> URL {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mp3]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true

        let response = await panel.beginAsync()
        guard response == .OK, let url = panel.url else {
            throw Error.userCancelled
        }
        return url
    }

    @MainActor
    private func pickFolder() async throws -> URL {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Exporter ici"

        let response = await panel.beginAsync()
        guard response == .OK, let url = panel.url else {
            throw Error.userCancelled
        }
        return url
    }

    nonisolated private func encode(pcmFileURL: URL, to destination: URL) async throws {
        let sourceFile = try AVAudioFile(forReading: pcmFileURL)
        let format = sourceFile.processingFormat
        let sampleRate = Int32(format.sampleRate)
        let channels = format.channelCount

        guard let lame = lame_init() else {
            throw Error.writeFailed("lame_init() a retourné nil")
        }
        defer { lame_close(lame) }

        lame_set_in_samplerate(lame, sampleRate)
        lame_set_num_channels(lame, Int32(channels))
        lame_set_VBR(lame, vbr_default)
        lame_set_VBR_quality(lame, 2)

        guard lame_init_params(lame) >= 0 else {
            throw Error.writeFailed("lame_init_params() a échoué")
        }

        FileManager.default.createFile(atPath: destination.path, contents: nil)
        let handle = try FileHandle(forWritingTo: destination)
        defer { try? handle.close() }

        let chunkFrames: AVAudioFrameCount = 8192
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) else {
            throw Error.writeFailed("Impossible de créer le buffer PCM")
        }

        let mp3BufSize = Int(1.25 * Double(chunkFrames) + 7200)
        var mp3Buf = [UInt8](repeating: 0, count: mp3BufSize)

        while sourceFile.framePosition < sourceFile.length {
            try sourceFile.read(into: buffer)
            let frames = Int32(buffer.frameLength)
            guard frames > 0 else { break }

            let left = buffer.floatChannelData![0]
            let right = channels > 1 ? buffer.floatChannelData![1] : left

            let written = lame_encode_buffer_ieee_float(
                lame,
                left,
                right,
                frames,
                &mp3Buf,
                Int32(mp3BufSize)
            )

            if written < 0 {
                throw Error.writeFailed("lame_encode a retourné \(written)")
            }
            if written > 0 {
                handle.write(Data(bytes: mp3Buf, count: Int(written)))
            }
        }

        let flushed = lame_encode_flush(lame, &mp3Buf, Int32(mp3BufSize))
        if flushed > 0 {
            handle.write(Data(bytes: mp3Buf, count: Int(flushed)))
        }
    }
}

private extension NSSavePanel {
    func beginAsync() async -> NSApplication.ModalResponse {
        await withCheckedContinuation { continuation in
            self.begin { response in
                continuation.resume(returning: response)
            }
        }
    }
}
