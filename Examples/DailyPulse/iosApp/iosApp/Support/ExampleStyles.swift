import SwiftUI

struct ExampleCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                Color.secondary.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 16)
            )
    }
}

struct ExampleHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

extension View {
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
