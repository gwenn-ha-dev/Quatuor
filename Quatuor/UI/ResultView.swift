import SwiftUI

/// Displays the separated stems with synchronized multi-track playback,
/// per-stem mute/solo/volume, waveform seek, and MP3 export.
struct ResultView: View {
    @Environment(AppState.self) private var state
    let result: SeparationResult
    var player = StemPlayer.shared
    @State private var exportError: String?
    @State private var isExportingAll = false

    var body: some View {
        VStack(spacing: 0) {
            header
            transportBar

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(result.stems) { stem in
                        StemRowView(
                            stem: stem,
                            player: player,
                            onExportError: { exportError = $0 }
                        )
                    }
                }
                .padding(24)
            }
        }
        .onAppear { player.load(stems: result.stems) }
        .onDisappear { player.unload() }
        .alert("Erreur d'export", isPresented: .init(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK") { exportError = nil }
        } message: {
            Text(exportError ?? "")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.source.displayName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(result.stems.count) stems prêts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Button {
                Task { await exportAll() }
            } label: {
                if isExportingAll {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Tout exporter", systemImage: "square.and.arrow.up")
                }
            }
            .disabled(isExportingAll)

            Button {
                player.unload()
                state.reset()
            } label: {
                Label("Nouveau", systemImage: "arrow.uturn.backward")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var transportBar: some View {
        HStack(spacing: 16) {
            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])

            Button {
                player.stop()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(!player.isPlaying && player.progress == 0)

            Text(formatTime(player.progress * player.duration))
                .font(.body.monospacedDigit())
                .frame(width: 48, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                        .frame(height: 6)
                    Capsule()
                        .fill(.tint)
                        .frame(width: geo.size.width * player.progress, height: 6)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let fraction = max(0, min(1, value.location.x / geo.size.width))
                            player.seek(fraction: fraction)
                        }
                )
            }
            .frame(height: 20)

            Text(formatTime(player.duration))
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.5))
    }

    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    @MainActor
    private func exportAll() async {
        isExportingAll = true
        defer { isExportingAll = false }
        do {
            let baseName = result.source.displayName
                .replacingOccurrences(of: ".\(result.source.url.pathExtension)", with: "")
            try await MP3Encoder.shared.exportAll(
                stems: result.stems,
                baseName: baseName
            )
        } catch MP3Encoder.Error.userCancelled {
            // User dismissed the folder picker.
        } catch {
            exportError = error.localizedDescription
        }
    }
}

/// A single stem row: mute/solo, volume control, waveform with shared progress, and MP3 export.
struct StemRowView: View {
    let stem: SeparationResult.Stem
    let player: StemPlayer
    var onExportError: (String) -> Void
    @State private var isExporting = false

    private var track: StemPlayer.TrackState {
        player.tracks[stem.id] ?? .init()
    }

    /// True if this track is effectively silent (muted, or not soloed while another is).
    private var isSilenced: Bool {
        track.isMuted || (player.hasSolo && !track.isSoloed)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 6) {
                Button {
                    player.toggleMute(for: stem.id)
                } label: {
                    Image(systemName: track.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundStyle(track.isMuted ? .secondary : tint)
                }
                .buttonStyle(.plain)

                Button {
                    player.toggleSolo(for: stem.id)
                } label: {
                    Text("S")
                        .font(.caption.bold())
                        .foregroundStyle(track.isSoloed ? .black : .secondary)
                        .frame(width: 22, height: 22)
                        .background(
                            track.isSoloed ? Color.yellow : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(track.isSoloed ? Color.yellow : .secondary.opacity(0.5), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .frame(width: 32)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    Text(stem.kind.label)
                        .font(.headline)
                        .frame(width: 72, alignment: .leading)

                    Slider(
                        value: Binding(
                            get: { track.volume },
                            set: { player.setVolume($0, for: stem.id) }
                        ),
                        in: 0...1
                    )
                    .tint(tint)
                    .frame(maxWidth: 120)
                }

                GeometryReader { geo in
                    WaveformView(
                        peaks: stem.waveformPeaks,
                        tint: isSilenced ? .gray : tint,
                        playbackProgress: player.isPlaying || player.progress > 0 ? player.progress : nil
                    )
                    .opacity(isSilenced ? 0.4 : 1.0)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let fraction = max(0, min(1, value.location.x / geo.size.width))
                                player.seek(fraction: fraction)
                            }
                    )
                }
                .frame(height: 48)
            }

            Spacer(minLength: 8)

            Button {
                Task { await exportMP3() }
            } label: {
                if isExporting {
                    ProgressView().controlSize(.small)
                } else {
                    Label("MP3", systemImage: "arrow.down.circle")
                }
            }
            .disabled(isExporting)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.background.tertiary)
        )
    }

    private var tint: Color {
        switch stem.kind {
        case .vocals: .pink
        case .drums:  .orange
        case .bass:   .purple
        case .other:  .teal
        }
    }

    @MainActor
    private func exportMP3() async {
        isExporting = true
        defer { isExporting = false }
        do {
            try await MP3Encoder.shared.export(
                pcmFileURL: stem.pcmFileURL,
                suggestedName: "\(stem.kind.rawValue).mp3"
            )
        } catch MP3Encoder.Error.userCancelled {
            // User dismissed the save panel.
        } catch {
            onExportError(error.localizedDescription)
        }
    }
}
