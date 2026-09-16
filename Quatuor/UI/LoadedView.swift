import SwiftUI

struct LoadedView: View {
    @Environment(AppState.self) private var state
    let source: LoadedSource

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text(source.displayName)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(metadataLabel)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            WaveformView(peaks: source.waveformPeaks, tint: .accentColor)
                .frame(height: 120)
                .padding(.horizontal, 40)

            HStack(spacing: 12) {
                Button(role: .cancel) {
                    state.reset()
                } label: {
                    Label("Annuler", systemImage: "xmark.circle")
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button {
                    Task { await separate() }
                } label: {
                    Label("Séparer les stems", systemImage: "waveform.path.badge.plus")
                        .padding(.horizontal, 8)
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var metadataLabel: String {
        let mins = Int(source.durationSeconds) / 60
        let secs = Int(source.durationSeconds) % 60
        return String(
            format: "%d:%02d · %.1f kHz · %d ch",
            mins, secs,
            source.sampleRate / 1000,
            source.channelCount
        )
    }

    private func separate() async {
        do {
            if !ModelManager.shared.isModelDownloaded {
                state.phase = .downloading(progress: 0)
                try await ModelManager.shared.ensureModel { progress in
                    Task { @MainActor in
                        state.phase = .downloading(progress: progress)
                    }
                }
            }

            state.phase = .processing(progress: 0)
            let result = try await SeparationPipeline.shared.run(source: source) { progress in
                Task { @MainActor in
                    state.phase = .processing(progress: progress)
                }
            }
            state.phase = .done(result)
        } catch {
            state.phase = .failed(error.localizedDescription)
        }
    }
}
