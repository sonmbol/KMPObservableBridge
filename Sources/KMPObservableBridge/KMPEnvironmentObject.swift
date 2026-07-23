import SwiftUI

/// Reads an existing KMP ViewModel store from SwiftUI's environment.
///
/// Inject `$viewModel` from `KMPStateObject` or `KMPObservedObject`. Missing
/// stores fail with SwiftUI's standard missing-`EnvironmentObject` diagnostic.
@MainActor
@propertyWrapper
public struct KMPEnvironmentObject<ViewModel: AnyObject>: DynamicProperty {
    @EnvironmentObject private var storage: KMPViewModelStore<ViewModel>

    public init() {}

    public var wrappedValue: ViewModel {
        storage.value
    }

    public var projectedValue: KMPViewModelStore<ViewModel> {
        storage
    }
}

public extension View {
    /// Injects an already-observed KMP store without creating subscriptions.
    @MainActor
    func kmpEnvironmentObject<ViewModel: AnyObject>(
        _ store: KMPViewModelStore<ViewModel>
    ) -> some View {
        environmentObject(store)
    }
}
