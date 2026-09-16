import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct DropZoneView: View {
    @Environment(AppState.self) private var state
    @State private var isHovering = false

    private static let audioTypes: [UTType] = [.mp3, .wav, .aiff, .mpeg4Audio, .audio]

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform")
                .font(.system(size: 72, weight: .ultraLight))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, options: .repeat(.continuous), isActive: !isHovering)

            Text("Glisse un fichier audio ici")
                .font(.title2.weight(.medium))
            Text("MP3 · WAV · AIFF · M4A")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button {
                Task { await pickFile() }
            } label: {
                Label("Parcourir…", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .keyboardShortcut("o", modifiers: .command)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    isHovering ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(isHovering ? 0.7 : 0.4))
                )
        }
        .padding(32)
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.smooth(duration: 0.2), value: isHovering)
        .onDrop(of: [.fileURL], isTargeted: $isHovering) { providers in
            guard let provider = providers.first else { return false }
            Task { @MainActor in
                await handleDrop(provider)
            }
            return true
        }
    }

    @MainActor
    private func handleDrop(_ provider: NSItemProvider) async {
        do {
            guard let url = try await provider.loadFileURL() else { return }
            await loadAudio(at: url)
        } catch {
            state.phase = .failed("Impossible de lire le fichier déposé : \(error.localizedDescription)")
        }
    }

    @MainActor
    private func pickFile() async {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = Self.audioTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        let response = await panel.begin()
        guard response == .OK, let url = panel.url else { return }
        await loadAudio(at: url)
    }

    @MainActor
    private func loadAudio(at url: URL) async {
        _ = url.startAccessingSecurityScopedResource()
        state.phase = .loading(fileName: url.lastPathComponent)
        do {
            let source = try await AudioDecoder.preview(url: url)
            state.phase = .loaded(source)
        } catch {
            state.phase = .failed("Impossible de lire \(url.lastPathComponent) : \(error.localizedDescription)")
        }
    }
}

extension NSItemProvider {
    func loadFileURL() async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let data = data as? Data,
                      let path = String(data: data, encoding: .utf8),
                      let url = URL(string: path) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: url)
            }
        }
    }
}
