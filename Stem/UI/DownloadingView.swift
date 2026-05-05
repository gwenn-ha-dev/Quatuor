import SwiftUI

struct DownloadingView: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, options: .repeat(.continuous))

            Text("Téléchargement du modèle…")
                .font(.title3.weight(.medium))

            Text("htdemucs_ft · ~336 Mo · première utilisation uniquement")
                .font(.caption)
                .foregroundStyle(.secondary)

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
