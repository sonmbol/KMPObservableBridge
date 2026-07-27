import SwiftUI

public extension View {
    /// Injects an already-observed KMP store without creating subscriptions.
    @MainActor
    func kmpEnvironmentObject<ViewModel: AnyObject>(
        _ store: KMPViewModelStore<ViewModel>
    ) -> some View {
        environmentObject(store)
    }
}
