import SwiftUI

/// Observes a KMP ViewModel owned outside this SwiftUI view.
@MainActor
@propertyWrapper
public struct KMPObservedObject<ViewModel: AnyObject>: @preconcurrency DynamicProperty {
    @StateObject private var storage: KMPViewModelStore<ViewModel>
    private let input: ViewModel
    private let states: [KMPState<ViewModel>]

    public var wrappedValue: ViewModel {
        storage.value
    }

    public var projectedValue: KMPViewModelStore<ViewModel> {
        storage
    }

    public init(
        wrappedValue viewModel: ViewModel,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log
    ) where ViewModel: KMPAutomaticallyObservable {
        self.init(
            viewModel,
            adapterArray: [
                .callback { viewModel, notify, reportError in
                    viewModel.kmpObserveAutomatically(
                        notify: notify,
                        reportError: reportError
                    )
                },
            ],
            updatePolicy: updatePolicy,
            failurePolicy: failurePolicy
        )
    }

    public init(
        _ viewModel: ViewModel,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log
    ) where ViewModel: KMPAutomaticallyObservable {
        self.init(
            viewModel,
            adapterArray: [
                .callback { viewModel, notify, reportError in
                    viewModel.kmpObserveAutomatically(
                        notify: notify,
                        reportError: reportError
                    )
                },
            ],
            updatePolicy: updatePolicy,
            failurePolicy: failurePolicy
        )
    }

    public init<Sequence: AsyncSequence>(
        wrappedValue viewModel: ViewModel,
        state: KeyPath<ViewModel, Sequence>,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log
    ) {
        self.init(
            viewModel,
            state: state,
            updatePolicy: updatePolicy,
            failurePolicy: failurePolicy
        )
    }

    public init<Output, Failure: Error, Unit>(
        wrappedValue viewModel: ViewModel,
        state: KeyPath<
            ViewModel,
            KMPNativeFlow<Output, Failure, Unit>
        >,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log
    ) {
        self.init(
            viewModel,
            state: state,
            updatePolicy: updatePolicy,
            failurePolicy: failurePolicy
        )
    }

    public init<First: AsyncSequence, each Sequence: AsyncSequence>(
        wrappedValue viewModel: ViewModel,
        states first: KeyPath<ViewModel, First>,
        _ states: repeat KeyPath<ViewModel, each Sequence>,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log
    ) {
        self.init(
            viewModel,
            adapterArray: [.asyncSequence(first)]
                + KMPState<ViewModel>.asyncSequences(repeat each states),
            updatePolicy: updatePolicy,
            failurePolicy: failurePolicy
        )
    }

    public init(
        wrappedValue viewModel: ViewModel,
        adapters first: KMPState<ViewModel>,
        _ adapters: KMPState<ViewModel>...,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log
    ) {
        self.init(
            viewModel,
            adapterArray: [first] + adapters,
            updatePolicy: updatePolicy,
            failurePolicy: failurePolicy
        )
    }

    public init<Sequence: AsyncSequence>(
        _ viewModel: ViewModel,
        state: KeyPath<ViewModel, Sequence>,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log
    ) {
        self.init(
            viewModel,
            adapterArray: [.asyncSequence(state)],
            updatePolicy: updatePolicy,
            failurePolicy: failurePolicy
        )
    }

    public init<Output, Failure: Error, Unit>(
        _ viewModel: ViewModel,
        state: KeyPath<
            ViewModel,
            KMPNativeFlow<Output, Failure, Unit>
        >,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log
    ) {
        self.init(
            viewModel,
            adapterArray: [.nativeFlow(state)],
            updatePolicy: updatePolicy,
            failurePolicy: failurePolicy
        )
    }

    public init<First: AsyncSequence, each Sequence: AsyncSequence>(
        _ viewModel: ViewModel,
        states first: KeyPath<ViewModel, First>,
        _ states: repeat KeyPath<ViewModel, each Sequence>,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log
    ) {
        self.init(
            viewModel,
            adapterArray: [.asyncSequence(first)]
                + KMPState<ViewModel>.asyncSequences(repeat each states),
            updatePolicy: updatePolicy,
            failurePolicy: failurePolicy
        )
    }

    public init(
        _ viewModel: ViewModel,
        adapters first: KMPState<ViewModel>,
        _ adapters: KMPState<ViewModel>...,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log
    ) {
        self.init(
            viewModel,
            adapterArray: [first] + adapters,
            updatePolicy: updatePolicy,
            failurePolicy: failurePolicy
        )
    }

    private init(
        _ viewModel: ViewModel,
        adapterArray: [KMPState<ViewModel>],
        updatePolicy: KMPUpdatePolicy,
        failurePolicy: KMPObservationFailurePolicy
    ) {
        input = viewModel
        states = adapterArray
        _storage = StateObject(
            wrappedValue: KMPViewModelStore(
                viewModel,
                states: adapterArray,
                updatePolicy: updatePolicy,
                failurePolicy: failurePolicy,
                ownsModel: false
            )
        )
    }

    public mutating func update() {
        _storage.update()
        storage.rebind(to: input, states: states)
    }
}
