import Combine
import SwiftUI

@MainActor
private final class KMPObservedObjectHolder<ViewModel: AnyObject>:
    @preconcurrency ObservableObject
{
    let objectWillChange = ObservableObjectPublisher()
    let store: KMPViewModelStore<ViewModel>?
    private var forwarding: AnyCancellable?

    init(store: KMPViewModelStore<ViewModel>?) {
        self.store = store
        forwarding = store?.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }
    }
}

/// Observes a KMP ViewModel owned outside this SwiftUI view.
@MainActor
@propertyWrapper
public struct KMPObservedObject<ViewModel: AnyObject>: @preconcurrency DynamicProperty {
    @StateObject private var holder: KMPObservedObjectHolder<ViewModel>
    private let input: ViewModel?
    private let states: [KMPState<ViewModel>]

    public var wrappedValue: ViewModel {
        requiredStore.value
    }

    public var projectedValue: KMPViewModelStore<ViewModel> {
        requiredStore
    }

    /// Declares deferred experimental SKIE observation.
    ///
    /// Assign the backing wrapper in the enclosing view's initializer. Access
    /// before that assignment is a programmer error and traps with a message.
    public init(
        observation: KMPAutomaticObservation
    ) {
        input = nil
        states = []
        _holder = StateObject(
            wrappedValue: KMPObservedObjectHolder(store: nil)
        )
    }

    /// Observes an external model using an explicitly selected integration.
    public init(
        _ viewModel: ViewModel,
        observation: KMPAutomaticObservation,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log
    ) {
        let enablesAutomaticDiscovery: Bool
        switch observation {
        case .none:
            enablesAutomaticDiscovery = false
        case .automaticSKIE:
            enablesAutomaticDiscovery = true
        }
        self.init(
            viewModel,
            adapterArray: [],
            updatePolicy: updatePolicy,
            failurePolicy: failurePolicy,
            automaticStateFlowDiscovery: enablesAutomaticDiscovery
        )
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
        failurePolicy: KMPObservationFailurePolicy,
        automaticStateFlowDiscovery: Bool = false
    ) {
        input = viewModel
        states = adapterArray
        let store = KMPViewModelStore(
                viewModel,
                states: adapterArray,
                updatePolicy: updatePolicy,
                failurePolicy: failurePolicy,
                ownsModel: false,
                automaticStateFlowDiscovery: automaticStateFlowDiscovery
            )
        _holder = StateObject(
            wrappedValue: KMPObservedObjectHolder(store: store)
        )
    }

    public mutating func update() {
        _holder.update()
        guard let input, let store = holder.store else {
            return
        }
        store.rebind(to: input, states: states)
    }

    private var requiredStore: KMPViewModelStore<ViewModel> {
        guard let store = holder.store else {
            preconditionFailure(
                "KMPObservedObject must be initialized by assigning its "
                    + "backing storage in the enclosing view initializer."
            )
        }
        return store
    }
}
