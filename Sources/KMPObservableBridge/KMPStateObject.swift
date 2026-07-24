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

    /// Creates and owns a model using automatic observation by default.
    ///
    /// Explicit automatic contracts such as `KMPNativeObservable` are checked
    /// first. Other models use SKIE discovery unless `.none` is selected.
    public init(
        wrappedValue makeViewModel: @autoclosure @escaping () -> ViewModel,
        observation: KMPAutomaticObservation = .automaticSKIE,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log,
        dispose: (@MainActor (ViewModel) -> Void)? = nil
    ) {
        let viewModel = makeViewModel()
        let source = kmpAutomaticObservationSource(
            for: viewModel,
            strategy: observation
        )
        _storage = StateObject(
            wrappedValue: KMPViewModelStore(
                viewModel,
                source: source,
                updatePolicy: updatePolicy,
                failurePolicy: failurePolicy,
                ownsModel: true,
                disposer: dispose
            )
        )
    }

    /// Resolves and owns an injected model using automatic observation.
    public init<Injector>(
        injector makeInjector: @autoclosure @escaping () -> Injector,
        viewModel keyPath: KeyPath<Injector, ViewModel>,
        observation: KMPAutomaticObservation = .automaticSKIE,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log,
        dispose: (@MainActor (ViewModel) -> Void)? = nil
    ) {
        let viewModel = makeInjector()[keyPath: keyPath]
        let source = kmpAutomaticObservationSource(
            for: viewModel,
            strategy: observation
        )
        _storage = StateObject(
            wrappedValue: KMPViewModelStore(
                viewModel,
                source: source,
                updatePolicy: updatePolicy,
                failurePolicy: failurePolicy,
                ownsModel: true,
                disposer: dispose
            )
        )
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

    /// Creates a model and observes a KMP-NativeCoroutines flow directly.
    public init<Output, Failure: Error, Unit>(
        wrappedValue makeViewModel: @autoclosure @escaping () -> ViewModel,
        state: KeyPath<
            ViewModel,
            KMPNativeFlow<Output, Failure, Unit>
        >,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log,
        dispose: (@MainActor (ViewModel) -> Void)? = nil
    ) {
        _storage = StateObject(
            wrappedValue: KMPViewModelStore(
                makeViewModel(),
                states: [.nativeFlow(state)],
                updatePolicy: updatePolicy,
                failurePolicy: failurePolicy,
                ownsModel: true,
                disposer: dispose
            )
        )
    }

    /// Creates a model and observes any number of heterogeneous streams.
    public init<First: AsyncSequence, each Sequence: AsyncSequence>(
        wrappedValue makeViewModel: @autoclosure @escaping () -> ViewModel,
        states first: KeyPath<ViewModel, First>,
        _ states: repeat KeyPath<ViewModel, each Sequence>,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log,
        dispose: (@MainActor (ViewModel) -> Void)? = nil
    ) {
        let sources = [.asyncSequence(first)]
            + KMPState<ViewModel>.asyncSequences(repeat each states)
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
        adapters first: KMPState<ViewModel>,
        _ adapters: KMPState<ViewModel>...,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log,
        dispose: (@MainActor (ViewModel) -> Void)? = nil
    ) {
        _storage = StateObject(
            wrappedValue: KMPViewModelStore(
                makeViewModel(),
                states: [first] + adapters,
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

    /// Resolves a model and observes a KMP-NativeCoroutines flow directly.
    public init<Injector, Output, Failure: Error, Unit>(
        injector makeInjector: @autoclosure @escaping () -> Injector,
        viewModel keyPath: KeyPath<Injector, ViewModel>,
        state: KeyPath<
            ViewModel,
            KMPNativeFlow<Output, Failure, Unit>
        >,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log,
        dispose: (@MainActor (ViewModel) -> Void)? = nil
    ) {
        _storage = StateObject(
            wrappedValue: KMPViewModelStore(
                makeInjector()[keyPath: keyPath],
                states: [.nativeFlow(state)],
                updatePolicy: updatePolicy,
                failurePolicy: failurePolicy,
                ownsModel: true,
                disposer: dispose
            )
        )
    }

    /// Resolves a model lazily and observes any number of state streams.
    public init<Injector, First: AsyncSequence, each Sequence: AsyncSequence>(
        injector makeInjector: @autoclosure @escaping () -> Injector,
        viewModel keyPath: KeyPath<Injector, ViewModel>,
        states first: KeyPath<ViewModel, First>,
        _ states: repeat KeyPath<ViewModel, each Sequence>,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log,
        dispose: (@MainActor (ViewModel) -> Void)? = nil
    ) {
        let sources = [.asyncSequence(first)]
            + KMPState<ViewModel>.asyncSequences(repeat each states)
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
        adapters first: KMPState<ViewModel>,
        _ adapters: KMPState<ViewModel>...,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log,
        dispose: (@MainActor (ViewModel) -> Void)? = nil
    ) {
        _storage = StateObject(
            wrappedValue: KMPViewModelStore(
                makeInjector()[keyPath: keyPath],
                states: [first] + adapters,
                updatePolicy: updatePolicy,
                failurePolicy: failurePolicy,
                ownsModel: true,
                disposer: dispose
            )
        )
    }
}
