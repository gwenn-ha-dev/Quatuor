import SwiftUI

/// Root view — routes to the appropriate screen based on the current `AppState.Phase`.
struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        ZStack {
            backgroundLayer

            switch state.phase {
            case .idle:
                DropZoneView()
            case .loading(let fileName):
                LoadingView(fileName: fileName)
            case .loaded(let source):
                LoadedView(source: source)
            case .processing(let progress):
                ProcessingView(progress: progress)
            case .done(let result):
                ResultView(result: result)
            case .failed(let message):
                FailureView(message: message)
            }
        }
        .animation(.smooth(duration: 0.35), value: phaseKey)
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [Color(nsColor: .windowBackgroundColor),
                     Color(nsColor: .underPageBackgroundColor)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var phaseKey: String {
        switch state.phase {
        case .idle: "idle"
        case .loading: "loading"
        case .loaded: "loaded"
        case .processing: "processing"
        case .done: "done"
        case .failed: "failed"
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .frame(width: 800, height: 520)
}
