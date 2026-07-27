import Combine

/// Coordinates parent-flow and current-child observation.
///
/// The Kotlin parent remains the lifecycle owner of every child.
@MainActor
final class KMPOptionalChildStore<Parent: AnyObject, Child: AnyObject>:
    @preconcurrency ObservableObject
{
    let objectWillChange = ObservableObjectPublisher()
    private(set) var child: Child?
    private(set) var childStore: KMPViewModelStore<Child>?

    private var parent: Parent
    private var currentChild: @MainActor (Parent) -> Child?
    private let childStates: [KMPState<Child>]
    private let updatePolicy: KMPUpdatePolicy
    private let failurePolicy: KMPObservationFailurePolicy
    private var parentObservation: KMPObservation?
    private var childSubscription: AnyCancellable?
    private var generation: UInt = 0

    init(
        parent: Parent,
        parentState: KMPState<Parent>,
        currentChild: @escaping @MainActor (Parent) -> Child?,
        childStates: [KMPState<Child>],
        updatePolicy: KMPUpdatePolicy,
        failurePolicy: KMPObservationFailurePolicy
    ) {
        self.parent = parent
        self.currentChild = currentChild
        self.childStates = childStates
        self.updatePolicy = updatePolicy
        self.failurePolicy = failurePolicy
        replaceChild(with: currentChild(parent))
        startParentObservation(parentState)
    }

    func rebind(
        to parent: Parent,
        parentState: KMPState<Parent>,
        currentChild: @escaping @MainActor (Parent) -> Child?
    ) {
        guard self.parent !== parent else {
            return
        }

        generation &+= 1
        parentObservation?.cancel()
        parentObservation = nil
        self.parent = parent
        self.currentChild = currentChild
        replaceChild(with: currentChild(parent))
        startParentObservation(parentState)
    }

    deinit {
        MainActor.assumeIsolated {
            generation &+= 1
            parentObservation?.cancel()
            childSubscription?.cancel()
        }
    }

    private func startParentObservation(_ state: KMPState<Parent>) {
        generation &+= 1
        let activeGeneration = generation
        parentObservation = state.observe(
            parent,
            { @MainActor [weak self] in
                guard
                    let self,
                    self.generation == activeGeneration
                else {
                    return
                }
                self.replaceChild(with: self.currentChild(self.parent))
            },
            { @MainActor [weak self] error in
                guard
                    let self,
                    self.generation == activeGeneration
                else {
                    return
                }
                self.failurePolicy.report(error)
            }
        )
    }

    private func replaceChild(with replacement: Child?) {
        if let child, let replacement, child === replacement {
            return
        }
        if child == nil, replacement == nil {
            return
        }

        childSubscription?.cancel()
        childSubscription = nil
        childStore = nil
        child = replacement

        if let replacement {
            let store = KMPViewModelStore(
                replacement,
                states: childStates,
                updatePolicy: updatePolicy,
                failurePolicy: failurePolicy,
                ownsModel: false,
                modernObservationEnabled: false
            )
            childSubscription = store.objectWillChange.sink { [weak self] in
                self?.objectWillChange.send()
            }
            childStore = store
        }
        objectWillChange.send()
    }
}
