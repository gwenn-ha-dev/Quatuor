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
                    Task { await state.separate(source) }
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

    /// "3:42 · 44.1 kHz · 2 channels" — or "3:42 · 44,1 kHz · 2 canaux": every
    /// part follows the app's language, including the decimal separator.
    private var metadataLabel: String {
        let duration = Duration.seconds(source.durationSeconds)
            .formatted(.time(pattern: .minuteSecond(padMinuteToLength: 1, roundFractionalSeconds: .towardZero)))
        let rate = Measurement(value: source.sampleRate / 1000, unit: UnitFrequency.kilohertz)
            .formatted(.measurement(width: .abbreviated,
                                    numberFormatStyle: .number.precision(.fractionLength(1))))
        let channels = String(localized: "\(source.channelCount) canaux")
        return "\(duration) · \(rate) · \(channels)"
    }
}
