import SwiftUI
import shared
import KMPObservableBridgeSKIE

@KMPObservable(
    ArticleViewModel.self,
    fields: \.articleState
)
extension ArticleViewModel: @retroactive KMPStaticallyObservable {}

struct ArticleInjectorExampleView: View {
    @KMPStateObject(
        injector: ArticleInjector(),
        viewModel: \.articleViewModel
    )
    private var article

    var body: some View {
        NavigationView {
            ArticleContentView(viewModel: article)
                .navigationTitle("Macro SKIE")
        }
    }
}

private struct ArticleContentView: View {
    @KMPObservedObject private var article: ArticleViewModel

    init(viewModel: ArticleViewModel) {
        _article = KMPObservedObject(viewModel)
    }

    var body: some View {
        ArticleListContent(
            isLoading: article.articleState.isLoading,
            error: article.articleState.error,
            articles: article.articleState.articles.map(ArticleRowModel.init)
        )
    }
}

private struct ArticleRowModel: Identifiable {
    let title: String
    let description: String
    let date: String
    let imageURL: URL?

    var id: String {
        "\(title)|\(date)"
    }

    init(_ article: Article) {
        title = article.title
        description = article.description_
        date = article.date
        imageURL = URL(string: article.imageUrl)
    }

    init(
        title: String,
        description: String,
        date: String,
        imageURL: URL?
    ) {
        self.title = title
        self.description = description
        self.date = date
        self.imageURL = imageURL
    }
}

private struct ArticleListContent: View {
    let isLoading: Bool
    let error: String?
    let articles: [ArticleRowModel]

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading articles…")
            } else if let error {
                ArticleUnavailableView(
                    title: "Unable to Load Articles",
                    message: error,
                    systemImage: "exclamationmark.triangle"
                )
            } else if articles.isEmpty {
                ArticleUnavailableView(
                    title: "No Articles",
                    message: "There are no articles to show.",
                    systemImage: "newspaper"
                )
            } else {
                List(articles) { article in
                    ArticleRow(article: article)
                }
                .listStyle(.plain)
            }
        }
    }
}

private struct ArticleUnavailableView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage).font(.largeTitle)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

private struct ArticleRow: View {
    let article: ArticleRowModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: article.imageURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else if phase.error != nil {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Text(article.title).font(.headline)
            Text(article.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(article.date)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }
}

struct ArticleSKIEExampleView_Previews: PreviewProvider {
    private static let articles = [
        ArticleRowModel(
            title: "Kotlin state with native SwiftUI rendering",
            description: "The preview uses immutable Swift data and never starts Koin or a Kotlin collector.",
            date: "Today",
            imageURL: URL(string: "https://picsum.photos/800/400")
        ),
        ArticleRowModel(
            title: "Field-level Observation",
            description: "Only views reading the changed projected field are invalidated.",
            date: "Yesterday",
            imageURL: nil
        ),
    ]

    static var previews: some View {
        Group {
            NavigationView {
                ArticleListContent(
                    isLoading: false,
                    error: nil,
                    articles: articles
                )
                .navigationTitle("Macro SKIE")
            }
            .previewDisplayName("Articles")

            ArticleListContent(
                isLoading: true,
                error: nil,
                articles: []
            )
            .previewDisplayName("Loading")

            ArticleListContent(
                isLoading: false,
                error: nil,
                articles: []
            )
            .previewDisplayName("Empty")
        }
    }
}
