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
        BridgeExamplePanel(
            title: title,
            subtitle: subtitle,
            count: example.counterState.count,
            isLoading: example.counterState.isLoading,
            message: $example.messageState,
            searchText: $example.searchText,
            kotlinSearchText: $example.searchTextState,
            increment: example.increment,
            load: example.simulateLoading,
            reset: example.reset
        )
    }
}

private struct BridgeExamplePanel: View {
    let title: String
    let subtitle: String
    let count: Int32
    let isLoading: Bool
    let message: String
    @Binding var searchText: String
    let kotlinSearchText: String
    let increment: () -> Void
    let load: () -> Void
    let reset: () -> Void

    var body: some View {
        ExampleCard {
            ExampleHeader(
                title: title,
                subtitle: subtitle,
                systemImage: "square.stack.3d.up"
            )

            Divider().padding(.vertical, 4)

            HStack(alignment: .firstTextBaseline) {
                Text("\(count)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Spacer()
                if isLoading {
                    ProgressView()
                }
            }

            Text(message).foregroundColor(.secondary)

            TextField("Writable Kotlin search text", text: $searchText)
                .textFieldStyle(.roundedBorder)

            Text("Kotlin value: \(kotlinSearchText)")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Button("Increment", action: increment)
                    .primaryExampleButtonStyle()
                Button("Load", action: load)
                    .secondaryExampleButtonStyle()
                Button("Reset", action: reset)
                    .secondaryExampleButtonStyle()
            }
        }
    }
}

private struct OwnershipPanelPreview: View {
    @State private var searchText = "SwiftUI"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BridgeExamplePanel(
                title: "StateObject Owner",
                subtitle: "The parent owns the Kotlin ViewModel.",
                count: 42,
                isLoading: false,
                message: "Counter updated from Kotlin",
                searchText: $searchText,
                kotlinSearchText: searchText,
                increment: {},
                load: {},
                reset: {}
            )
        }
        .padding()
    }
}

struct OwnershipExamplesView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OwnershipPanelPreview()
                .previewDisplayName("Populated")

            OwnershipPanelPreview()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark mode")
        }
    }
}
