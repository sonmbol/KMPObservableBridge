import SwiftUI

/// Creates and owns a KMP ViewModel for a SwiftUI view identity.
@MainActor
@propertyWrapper
public struct KMPStateObject<ViewModel: AnyObject>: DynamicProperty {
    @StateObject private var storage: KMPViewModelStore<ViewModel>

    public var wrappedValue: ViewModel {
        storage.value
    }

    public var projectedValue: KMPViewModelStore<ViewModel> {
        storage
    }

    /// Creates a model and observes its primary state stream.
    public init<Sequence: AsyncSequence>(
        wrappedValue makeViewModel: @autoclosure @escaping () -> ViewModel,
        state: KeyPath<ViewModel, Sequence>,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log,
        dispose: (@MainActor (ViewModel) -> Void)? = nil
    ) {
        _storage = StateObject(
            wrappedValue: KMPViewModelStore(
                makeViewModel(),
                states: [.asyncSequence(state)],
                updatePolicy: updatePolicy,
                failurePolicy: failurePolicy,
                ownsModel: true,
                disposer: dispose
            )
        )
    }

    /// Creates a model and observes any number of heterogeneous streams.
    public init<each Sequence: AsyncSequence>(
        wrappedValue makeViewModel: @autoclosure @escaping () -> ViewModel,
        states: repeat KeyPath<ViewModel, each Sequence>,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log,
        dispose: (@MainActor (ViewModel) -> Void)? = nil
    ) {
        let sources = KMPState<ViewModel>.asyncSequences(repeat each states)
        _storage = StateObject(
            wrappedValue: KMPViewModelStore(
                makeViewModel(),
                states: sources,
                updatePolicy: updatePolicy,
                failurePolicy: failurePolicy,
                ownsModel: true,
                disposer: dispose
            )
        )
    }

    /// Creates a model with advanced or mixed observation adapters.
    public init(
        wrappedValue makeViewModel: @autoclosure @escaping () -> ViewModel,
        adapters: KMPState<ViewModel>...,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log,
        dispose: (@MainActor (ViewModel) -> Void)? = nil
    ) {
        _storage = StateObject(
            wrappedValue: KMPViewModelStore(
                makeViewModel(),
                states: adapters,
                updatePolicy: updatePolicy,
                failurePolicy: failurePolicy,
                ownsModel: true,
                disposer: dispose
            )
        )
    }

    /// Resolves a model lazily from an injector and observes one state stream.
    public init<Injector, Sequence: AsyncSequence>(
        injector makeInjector: @autoclosure @escaping () -> Injector,
        viewModel keyPath: KeyPath<Injector, ViewModel>,
        state: KeyPath<ViewModel, Sequence>,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log,
        dispose: (@MainActor (ViewModel) -> Void)? = nil
    ) {
        _storage = StateObject(
            wrappedValue: KMPViewModelStore(
                makeInjector()[keyPath: keyPath],
                states: [.asyncSequence(state)],
                updatePolicy: updatePolicy,
                failurePolicy: failurePolicy,
                ownsModel: true,
                disposer: dispose
            )
        )
    }

    /// Resolves a model lazily and observes any number of state streams.
    public init<Injector, each Sequence: AsyncSequence>(
        injector makeInjector: @autoclosure @escaping () -> Injector,
        viewModel keyPath: KeyPath<Injector, ViewModel>,
        states: repeat KeyPath<ViewModel, each Sequence>,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log,
        dispose: (@MainActor (ViewModel) -> Void)? = nil
    ) {
        let sources = KMPState<ViewModel>.asyncSequences(repeat each states)
        _storage = StateObject(
            wrappedValue: KMPViewModelStore(
                makeInjector()[keyPath: keyPath],
                states: sources,
                updatePolicy: updatePolicy,
                failurePolicy: failurePolicy,
                ownsModel: true,
                disposer: dispose
            )
        )
    }

    /// Resolves a model lazily with advanced or mixed adapters.
    public init<Injector>(
        injector makeInjector: @autoclosure @escaping () -> Injector,
        viewModel keyPath: KeyPath<Injector, ViewModel>,
        adapters: KMPState<ViewModel>...,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log,
        dispose: (@MainActor (ViewModel) -> Void)? = nil
    ) {
        _storage = StateObject(
            wrappedValue: KMPViewModelStore(
                makeInjector()[keyPath: keyPath],
                states: adapters,
                updatePolicy: updatePolicy,
                failurePolicy: failurePolicy,
                ownsModel: true,
                disposer: dispose
            )
        )
    }
}
