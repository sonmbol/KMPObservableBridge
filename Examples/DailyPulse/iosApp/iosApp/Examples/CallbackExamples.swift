import SwiftUI
import shared
import KMPObservableBridge

struct CallbackExamplesView: View {
    var body: some View {
        NavigationView {
            List {
                NavigationLink("Callback cancellation adapter") {
                    CallbackAdapterExampleView()
                }
                NavigationLink("Combine publisher adapter") {
                    CombineAdapterExampleView()
                }
            }
            .navigationTitle("Explicit Adapters")
        }
    }
}

private struct CallbackAdapterExampleView: View {
    @KMPStateObject(
        wrappedValue: BridgeExampleViewModel(),
        adapters: .callback { viewModel, notify, _ in
            let handle = viewModel.callbackState.watch { _ in
                Task { @MainActor in notify() }
            }
            return KMPObservation { handle.close() }
        }
    )
    private var example

    var body: some View {
        AdapterContent(
            title: "Callback",
            message: $example.callbackState,
            increment: example.increment,
            reset: example.reset
        )
    }
}

private struct CombineAdapterExampleView: View {
    @KMPStateObject(
        wrappedValue: BridgeExampleViewModel(),
        adapters: .publisher { $0.callbackPublisher }
    )
    private var example

    var body: some View {
        AdapterContent(
            title: "Combine",
            message: $example.callbackState,
            increment: example.increment,
            reset: example.reset
        )
    }
}

private struct AdapterContent: View {
    let title: String
    let message: String
    let increment: () -> Void
    let reset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ExampleCard {
                ExampleHeader(
                    title: title,
                    subtitle: "Explicit adapter with deterministic cancellation.",
                    systemImage: "arrow.triangle.2.circlepath"
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
        .navigationTitle("\(title) Adapter")
    }
}

struct CallbackExamplesView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                AdapterContent(
                    title: "Callback",
                    message: "Callback updated to 3",
                    increment: {},
                    reset: {}
                )
            }
            .previewDisplayName("Callback adapter")

            NavigationView {
                AdapterContent(
                    title: "Combine",
                    message: "Publisher delivered on MainActor",
                    increment: {},
                    reset: {}
                )
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Combine adapter")
        }
    }
}
