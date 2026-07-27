import SwiftUI
import shared
import KMPObservableBridgeSKIE

@KMPObservable(
    BridgeExampleViewModel.self,
    fields: \.counterState, \.messageState, \.searchTextState
)
extension BridgeExampleViewModel: @retroactive KMPStaticallyObservable {}

struct OwnershipExamplesView: View {
    @KMPStateObject private var example = BridgeExampleViewModel()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    BridgeExampleContentView(
                        title: "StateObject Owner",
                        subtitle: "The parent owns the Kotlin ViewModel.",
                        viewModel: example
                    )
                    Divider()
                    ObservedChildView(viewModel: example)
                    Divider()
                    EnvironmentChildView()
                        .kmpEnvironmentObject($example)
                }
                .padding()
            }
            .navigationTitle("SwiftUI Ownership")
        }
    }
}

private struct ObservedChildView: View {
    @KMPObservedObject private var example: BridgeExampleViewModel

    init(viewModel: BridgeExampleViewModel) {
        _example = KMPObservedObject(viewModel)
    }

    var body: some View {
        HStack {
            Label(
                "\(example.counterState.count)",
                systemImage: "rectangle.stack"
            )
            Spacer()
            Button("Increment from Child", action: example.increment)
        }
    }
}

private struct EnvironmentChildView: View {
    @KMPEnvironmentObject private var example: BridgeExampleViewModel

    var body: some View {
        HStack {
            Label(
                "\(example.counterState.count)",
                systemImage: "leaf"
            )
            Spacer()
            Text("Shared environment store")
                .foregroundColor(.secondary)
        }
    }
}

private struct BridgeExampleContentView: View {
    @KMPObservedObject private var example: BridgeExampleViewModel
    let title: String
    let subtitle: String

    init(
        title: String,
        subtitle: String,
        viewModel: BridgeExampleViewModel
    ) {
        self.title = title
        self.subtitle = subtitle
        _example = KMPObservedObject(viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.title2.bold())
            Text(subtitle).foregroundColor(.secondary)
            Text("\(example.counterState.count)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
            if example.counterState.isLoading {
                ProgressView()
            }
            Text($example.messageState).foregroundColor(.secondary)
            TextField("Writable Kotlin search text", text: $example.searchText)
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 4) {
                Text("Kotlin value:")
                Text($example.searchTextState)
            }
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                Button("Increment", action: example.increment)
                    .primaryExampleButtonStyle()
                Button("Load", action: example.simulateLoading)
                    .secondaryExampleButtonStyle()
                Button("Reset", action: example.reset)
                    .secondaryExampleButtonStyle()
            }
        }
    }
}
