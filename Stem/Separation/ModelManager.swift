import Foundation

@MainActor
final class ModelManager {
    static let shared = ModelManager()

    private static let repo = "iky1e/demucs-mlx"
    private static let modelName = "htdemucs_ft"
    private static let files = [
        "\(modelName).safetensors",
        "\(modelName)_config.json"
    ]

    var modelDirectory: URL {
        let appSupport = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("Stem", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent(Self.modelName, isDirectory: true)
    }

    var isModelDownloaded: Bool {
        let fm = FileManager.default
        return Self.files.allSatisfy { fm.fileExists(atPath: modelDirectory.appendingPathComponent($0).path) }
    }

    func ensureModel(progress: @escaping (Double) -> Void) async throws {
        if isModelDownloaded { return }
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)

        for (index, filename) in Self.files.enumerated() {
            let baseProgress = Double(index) / Double(Self.files.count)
            let fileWeight = 1.0 / Double(Self.files.count)
            let url = URL(string: "https://huggingface.co/\(Self.repo)/resolve/main/\(filename)")!
            let destination = modelDirectory.appendingPathComponent(filename)

            if FileManager.default.fileExists(atPath: destination.path) {
                progress(baseProgress + fileWeight)
                continue
            }

            try await download(from: url, to: destination) { fraction in
                progress(baseProgress + fraction * fileWeight)
            }
        }
        progress(1.0)
    }

    nonisolated private func download(
        from url: URL,
        to destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let delegate = DownloadDelegate(progress: progress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        let (tempURL, response) = try await session.download(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)
    }
}

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate, Sendable {
    let progress: @Sendable (Double) -> Void

    init(progress: @escaping @Sendable (Double) -> Void) {
        self.progress = progress
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        progress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handled in the async download call
    }
}
