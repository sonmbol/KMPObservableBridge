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
        Group {
            if article.articleState.isLoading {
                ProgressView()
            } else if article.articleState.articles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "newspaper").font(.largeTitle)
                    Text("No Articles").font(.headline)
                    Text("There are no articles to show.")
                        .foregroundColor(.secondary)
                }
            } else {
                List(article.articleState.articles, id: \.title) { article in
                    ArticleRow(article: article)
                }
                .listStyle(.plain)
            }
        }
    }
}

private struct ArticleRow: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.title).font(.headline)
            Text(article.description_)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(article.date)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 8)
    }
}
