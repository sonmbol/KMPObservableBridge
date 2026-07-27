import SwiftUI

/// Reads an existing KMP ViewModel store from SwiftUI's environment.
///
/// Inject `$viewModel` from `KMPStateObject` or `KMPObservedObject`. Missing
/// stores fail with SwiftUI's standard missing-`EnvironmentObject` diagnostic.
@MainActor
@propertyWrapper
public struct KMPEnvironmentObject<ViewModel: AnyObject>: DynamicProperty {
    @EnvironmentObject private var storage: KMPViewModelStore<ViewModel>

    /// Creates an environment reader without creating or assigning a store.
    ///
    /// This is intentional: SwiftUI resolves `storage` from the nearest
    /// `.kmpEnvironmentObject($viewModel)` ancestor when it updates this
    /// `DynamicProperty`. Initializing storage here would create a second store
    /// and duplicate the owner's subscriptions.
    public init() {}

    public var wrappedValue: ViewModel {
        storage.value
    }

    public var projectedValue: KMPViewModelStore<ViewModel> {
        storage
    }
}
