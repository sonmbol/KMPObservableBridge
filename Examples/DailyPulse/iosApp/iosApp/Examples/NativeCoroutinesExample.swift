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
            VStack(alignment: .leading, spacing: 16) {
                Text("KMP-NativeCoroutines")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("The ViewModel's canonical NativeFlow is observed explicitly.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(example.nativeMessageValue)
                    .font(.headline)

                HStack {
                    Button("Increment") {
                        example.increment()
                    }

                    Button("Reset") {
                        example.reset()
                    }
                }
            }
            .padding()
            .navigationTitle("NativeCoroutines")
        }
    }
}
