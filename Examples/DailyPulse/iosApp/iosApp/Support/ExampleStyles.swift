import SwiftUI

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
