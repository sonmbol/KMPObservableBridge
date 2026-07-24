import Combine
import SwiftUI

/// Observes a non-optional child ViewModel owned by a parent KMP model.
///
/// Use this wrapper when the parent exposes a synchronous `Child` property
/// whose value is guaranteed to exist. SwiftUI re-reads that property during
/// `update()` and the store rebinds if its object identity changes. No parent
/// flow subscription is needed, and `wrappedValue` remains non-optional.
@MainActor
@propertyWrapper
public struct KMPChildObject<Parent: AnyObject, Child: AnyObject>: @preconcurrency DynamicProperty {
    @StateObject private var storage: KMPViewModelStore<Child>
    private let parent: Parent
    private let childKeyPath: KeyPath<Parent, Child>
    private let states: [KMPState<Child>]

    public var wrappedValue: Child {
        storage.value
    }

    public var projectedValue: KMPViewModelStore<Child> {
        storage
    }

    public init<Sequence: AsyncSequence>(
        parent: Parent,
        child: KeyPath<Parent, Child>,
        state: KeyPath<Child, Sequence>,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log
    ) {
        let sources: [KMPState<Child>] = [.asyncSequence(state)]
        self.parent = parent
        childKeyPath = child
        states = sources
        _storage = StateObject(
            wrappedValue: KMPViewModelStore(
                parent[keyPath: child],
                states: sources,
                updatePolicy: updatePolicy,
                failurePolicy: failurePolicy,
                ownsModel: false
            )
        )
    }

    public init<each Sequence: AsyncSequence>(
        parent: Parent,
        child: KeyPath<Parent, Child>,
        states: repeat KeyPath<Child, each Sequence>,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log
    ) {
        let sources = KMPState<Child>.asyncSequences(repeat each states)
        self.parent = parent
        childKeyPath = child
        self.states = sources
        _storage = StateObject(
            wrappedValue: KMPViewModelStore(
                parent[keyPath: child],
                states: sources,
                updatePolicy: updatePolicy,
                failurePolicy: failurePolicy,
                ownsModel: false
            )
        )
    }

    public mutating func update() {
        _storage.update()
        storage.rebind(
            to: parent[keyPath: childKeyPath],
            states: states
        )
    }
}

/// Owns the two-level observation required by a Flow-backed optional child.
///
/// This is intentionally separate from `KMPChildObject`'s direct child store:
/// it must observe the parent flow, handle `nil` and identity transitions,
/// replace the child observation in deterministic order, and forward the
/// current child's invalidations. It is private implementation detail; the
/// parent continues to own the child lifecycle.
@MainActor
private final class KMPOptionalChildStore<Parent: AnyObject, Child: AnyObject>:
    @preconcurrency ObservableObject
{
    let objectWillChange = ObservableObjectPublisher()
    private(set) var child: Child?
    private(set) var childStore: KMPViewModelStore<Child>?

    private let parent: Parent
    private let currentChild: @MainActor () -> Child?
    private let childStates: [KMPState<Child>]
    private let updatePolicy: KMPUpdatePolicy
    private let failurePolicy: KMPObservationFailurePolicy
    private var parentObservation: KMPObservation?
    private var childSubscription: AnyCancellable?
    private var generation: UInt = 0

    init(
        parent: Parent,
        parentState: KMPState<Parent>,
        currentChild: @escaping @MainActor () -> Child?,
        childStates: [KMPState<Child>],
        updatePolicy: KMPUpdatePolicy,
        failurePolicy: KMPObservationFailurePolicy
    ) {
        self.parent = parent
        self.currentChild = currentChild
        self.childStates = childStates
        self.updatePolicy = updatePolicy
        self.failurePolicy = failurePolicy
        replaceChild(with: currentChild())
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
            { [weak self] in
                Task { @MainActor [weak self] in
                    guard
                        let self,
                        self.generation == activeGeneration
                    else {
                        return
                    }
                    self.replaceChild(with: self.currentChild())
                }
            },
            { [weak self] error in
                Task { @MainActor [weak self] in
                    guard
                        let self,
                        self.generation == activeGeneration
                    else {
                        return
                    }
                    self.failurePolicy.report(error)
                }
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

/// Observes an optional child ViewModel emitted by a parent state flow.
///
/// Unlike `KMPChildObject`, this wrapper subscribes to the parent flow because
/// the child may appear, disappear, or be replaced independently of SwiftUI
/// updates. Its `wrappedValue` and projected store are therefore optional.
/// Keeping a distinct wrapper preserves Kotlin nullability in Swift: guaranteed
/// children stay `Child`, while Flow-backed optional children remain `Child?`.
@MainActor
@propertyWrapper
public struct KMPOptionalChildObject<Parent: AnyObject, Child: AnyObject>:
    DynamicProperty
{
    @StateObject private var storage: KMPOptionalChildStore<Parent, Child>

    public var wrappedValue: Child? {
        storage.child
    }

    public var projectedValue: KMPViewModelStore<Child>? {
        storage.childStore
    }

    public init<Flow, Sequence: AsyncSequence>(
        parent: Parent,
        child: KeyPath<Parent, Flow>,
        state: KeyPath<Child, Sequence>,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log
    ) where
        Flow: AsyncSequence & KMPValueProperty,
        Flow.Element == Child?,
        Flow.Value == Child?
    {
        _storage = StateObject(
            wrappedValue: KMPOptionalChildStore(
                parent: parent,
                parentState: .asyncSequence(child),
                currentChild: { parent[keyPath: child].value },
                childStates: [.asyncSequence(state)],
                updatePolicy: updatePolicy,
                failurePolicy: failurePolicy
            )
        )
    }

    public init<Flow, each Sequence: AsyncSequence>(
        parent: Parent,
        child: KeyPath<Parent, Flow>,
        states: repeat KeyPath<Child, each Sequence>,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log
    ) where
        Flow: AsyncSequence & KMPValueProperty,
        Flow.Element == Child?,
        Flow.Value == Child?
    {
        _storage = StateObject(
            wrappedValue: KMPOptionalChildStore(
                parent: parent,
                parentState: .asyncSequence(child),
                currentChild: { parent[keyPath: child].value },
                childStates: KMPState<Child>.asyncSequences(
                    repeat each states
                ),
                updatePolicy: updatePolicy,
                failurePolicy: failurePolicy
            )
        )
    }
}
