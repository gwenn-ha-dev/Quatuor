import SwiftUI

struct LoadingView: View {
    let fileName: String

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)

            Text("Analyse de la waveform...")
                .font(.title3.weight(.medium))

            Text(fileName)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
