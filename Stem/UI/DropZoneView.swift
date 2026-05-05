import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @Environment(AppState.self) private var state
    @State private var isHovering = false

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
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            Task { @MainActor in
                await loadAudio(at: url)
            }
            return true
        } isTargeted: { hovering in
            isHovering = hovering
        }
    }

    @MainActor
    private func loadAudio(at url: URL) async {
        state.phase = .loading(fileName: url.lastPathComponent)
        do {
            let source = try await AudioDecoder.preview(url: url)
            state.phase = .loaded(source)
        } catch {
            state.phase = .failed(error.localizedDescription)
        }
    }
}
