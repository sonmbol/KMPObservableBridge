import SwiftUI
import shared
import KMPObservableBridge

extension BaseViewModel: @retroactive KMPDisposable {
    public func dispose() {
        clear()
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            ArticleInjectorExampleView()
                .tabItem {
                    Image(systemName: "newspaper")
                    Text("Injector")
                }

            DirectStateObjectExampleView()
                .tabItem {
                    Image(systemName: "bolt")
                    Text("Direct")
                }

            ObservedObjectExampleView()
                .tabItem {
                    Image(systemName: "rectangle.stack")
                    Text("Observed")
                }

            CallbackAdapterExampleView()
                .tabItem {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Callback")
                }

            CombineAdapterExampleView()
                .tabItem {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Combine")
                }
        }
    }
}

private struct ArticleInjectorExampleView: View {
    @KMPStateObject(
        injector: ArticleInjector(),
        viewModel: \.articleViewModel,
        state: \.articleState
    )
    private var article

	var body: some View {
        NavigationView {
            ArticleContentView(viewModel: article)
                .navigationTitle("Injector Example")
        }
	}
}

private struct ArticleContentView: View {
    @KMPObservedObject private var article: ArticleViewModel

    init(viewModel: ArticleViewModel) {
        _article = KMPObservedObject(
            viewModel,
            state: \.articleState
        )
    }

    var body: some View {
        Group {
            if article.articleState.isLoading {
                ProgressView()
            } else if article.articleState.articles.isEmpty {
                EmptyArticlesView(
                    title: "No Articles",
                    message: "There are no articles to show right now."
                )
            } else {
                List(article.articleState.articles, id: \.title) { item in
                    ArticleRow(article: item)
                }
                .listStyle(.plain)
            }
        }
    }
}

private struct DirectStateObjectExampleView: View {
    @KMPStateObject(
        wrappedValue: BridgeExampleViewModel(),
        states: \.counterState, \.messageState
    )
    private var example

    var body: some View {
        NavigationView {
            BridgeExampleContentView(
                title: "Direct StateObject",
                subtitle: "The view creates the KMP ViewModel directly.",
                viewModel: example
            )
            .navigationTitle("Direct Example")
        }
    }
}

private struct ObservedObjectExampleView: View {
    @KMPStateObject(
        wrappedValue: BridgeExampleViewModel(),
        states: \.counterState, \.messageState
    )
    private var example

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                BridgeExampleContentView(
                    title: "Parent Owner",
                    subtitle: "This parent owns the KMP ViewModel.",
                    viewModel: example
                )

                Divider()

                BridgeExampleChildView(viewModel: example)

                Divider()

                BridgeExampleEnvironmentView()
                    .kmpEnvironmentObject($example)
            }
            .padding()
            .navigationTitle("Observed Example")
        }
    }
}

private struct BridgeExampleEnvironmentView: View {
    @KMPEnvironmentObject private var example: BridgeExampleViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Environment Observer")
                .font(.headline)

            Text("Shares the parent's existing observation store.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Count: \(example.counterState.count)")
        }
    }
}

private struct BridgeExampleChildView: View {
    @KMPObservedObject private var example: BridgeExampleViewModel

    init(viewModel: BridgeExampleViewModel) {
        _example = KMPObservedObject(
            viewModel,
            states: \.counterState, \.messageState
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Child Observer")
                .font(.headline)

            Text("The child receives the parent-owned KMP ViewModel and observes the same state.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Label("\(example.counterState.count)", systemImage: "number")
                Spacer()
                Button("Increment from Child") {
                    example.increment()
                }
            }
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
        _example = KMPObservedObject(
            viewModel,
            states: \.counterState, \.messageState
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Count")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(example.counterState.count)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                }

                Spacer()

                if example.counterState.isLoading {
                    ProgressView()
                }
            }

            Text(example.messageState)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Button("Increment") {
                    example.increment()
                }
                .primaryExampleButtonStyle()

                Button("Load") {
                    example.simulateLoading()
                }
                .secondaryExampleButtonStyle()

                Button("Reset") {
                    example.reset()
                }
                .secondaryExampleButtonStyle()
            }
        }
        .padding()
    }
}

private struct CallbackAdapterExampleView: View {
    @KMPStateObject(
        wrappedValue: BridgeExampleViewModel(),
        adapters: .callback { viewModel, notify, _ in
            let handle = viewModel.callbackState.watch { _ in
                Task { @MainActor in
                    notify()
                }
            }

            return KMPObservation {
                handle.close()
            }
        }
    )
    private var example

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Callback Adapter")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("A custom KMP watch API invalidates SwiftUI through KMPObservation.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text(example.callbackState)
                    .font(.headline)

                HStack {
                    Button("Increment") {
                        example.increment()
                    }
                    .primaryExampleButtonStyle()

                    Button("Load") {
                        example.simulateLoading()
                    }
                    .secondaryExampleButtonStyle()

                    Button("Reset") {
                        example.reset()
                    }
                    .secondaryExampleButtonStyle()
                }
            }
            .padding()
            .navigationTitle("Callback Example")
        }
    }
}

private struct CombineAdapterExampleView: View {
    @KMPStateObject(
        wrappedValue: BridgeExampleViewModel(),
        adapters: .publisher { $0.callbackPublisher }
    )
    private var example

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Combine Adapter")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("An iOS Combine publisher invalidates SwiftUI from KMP state.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text(example.callbackState)
                    .font(.headline)

                HStack {
                    Button("Increment") {
                        example.increment()
                    }
                    .primaryExampleButtonStyle()

                    Button("Load") {
                        example.simulateLoading()
                    }
                    .secondaryExampleButtonStyle()

                    Button("Reset") {
                        example.reset()
                    }
                    .secondaryExampleButtonStyle()
                }
            }
            .padding()
            .navigationTitle("Combine Example")
        }
    }
}

private extension View {
    func primaryExampleButtonStyle() -> some View {
        padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func secondaryExampleButtonStyle() -> some View {
        padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.14))
            .foregroundColor(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ArticleRow: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RemoteArticleImage(url: URL(string: article.imageUrl))

            Text(article.title)
                .font(.headline)

            Text(article.description_)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(article.date)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }
}

private struct RemoteArticleImage: View {
    let url: URL?

    var body: some View {
        if #available(iOS 15.0, *) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholder
                case .empty:
                    ProgressView()
                @unknown default:
                    placeholder
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            placeholder
                .frame(height: 180)
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.secondary.opacity(0.12))
            .overlay(
                Image(systemName: "newspaper")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
            )
    }
}

private struct EmptyArticlesView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "newspaper")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		ContentView()
	}
}
