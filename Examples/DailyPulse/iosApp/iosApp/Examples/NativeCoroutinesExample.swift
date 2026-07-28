import SwiftUI
import shared
import KMPObservableBridgeNative

/// A real KMP-NativeCoroutines integration. Kotlin owns the current value;
/// the canonical NativeFlow supplies cancellable observation to the bridge.
struct NativeCoroutinesExampleView: View {
    @KMPStateObject(
        state: \.kmpObservationFlow,
        updatePolicy: .immediate
    )
    private var example = BridgeExampleViewModel()

    var body: some View {
        NavigationView {
            NativeCoroutinesContent(
                message: example.nativeMessageValue,
                increment: example.increment,
                reset: example.reset
            )
            .navigationTitle("NativeCoroutines")
        }
    }
}

private struct NativeCoroutinesContent: View {
    let message: String
    let increment: () -> Void
    let reset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ExampleCard {
                ExampleHeader(
                    title: "KMP-NativeCoroutines",
                    subtitle: "The canonical NativeFlow is observed explicitly.",
                    systemImage: "point.3.connected.trianglepath.dotted"
                )

                Divider().padding(.vertical, 4)

                Text(message).font(.headline)

                HStack {
                    Button("Increment", action: increment)
                        .primaryExampleButtonStyle()
                    Button("Reset", action: reset)
                        .secondaryExampleButtonStyle()
                }
            }
            Spacer()
        }
        .padding()
    }
}

struct NativeCoroutinesExampleView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NativeCoroutinesContent(
                message: "Counter updated to 8",
                increment: {},
                reset: {}
            )
            .navigationTitle("NativeCoroutines")
        }
        .previewDisplayName("NativeFlow adapter")
    }
}
