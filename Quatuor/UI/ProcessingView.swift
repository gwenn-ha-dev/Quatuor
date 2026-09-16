import SwiftUI

struct ProcessingView: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(.tint)
                .symbolEffect(.variableColor.iterative, options: .repeat(.continuous))

            Text("Séparation en cours…")
                .font(.title3.weight(.medium))

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(maxWidth: 360)

            Text("\(Int(progress * 100)) %")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(48)
    }
}
