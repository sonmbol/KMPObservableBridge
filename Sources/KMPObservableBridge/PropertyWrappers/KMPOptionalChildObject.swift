import SwiftUI

/// Observes an optional child ViewModel emitted by a parent state flow.
@MainActor
@propertyWrapper
public struct KMPOptionalChildObject<Parent: AnyObject, Child: AnyObject>:
    @preconcurrency DynamicProperty
{
    @StateObject private var storage: KMPOptionalChildStore<Parent, Child>
    private let parent: Parent
    private let parentState: KMPState<Parent>
    private let currentChild: @MainActor (Parent) -> Child?

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
        let parentState: KMPState<Parent> = .asyncSequence(child)
        self.parent = parent
        self.parentState = parentState
        currentChild = { $0[keyPath: child].value }
        _storage = StateObject(
            wrappedValue: KMPOptionalChildStore(
                parent: parent,
                parentState: parentState,
                currentChild: { $0[keyPath: child].value },
                childStates: [.asyncSequence(state)],
                updatePolicy: updatePolicy,
                failurePolicy: failurePolicy
            )
        )
    }

    public init<Flow, First: AsyncSequence, each Sequence: AsyncSequence>(
        parent: Parent,
        child: KeyPath<Parent, Flow>,
        states first: KeyPath<Child, First>,
        _ states: repeat KeyPath<Child, each Sequence>,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log
    ) where
        Flow: AsyncSequence & KMPValueProperty,
        Flow.Element == Child?,
        Flow.Value == Child?
    {
        let parentState: KMPState<Parent> = .asyncSequence(child)
        self.parent = parent
        self.parentState = parentState
        currentChild = { $0[keyPath: child].value }
        _storage = StateObject(
            wrappedValue: KMPOptionalChildStore(
                parent: parent,
                parentState: parentState,
                currentChild: { $0[keyPath: child].value },
                childStates: [.asyncSequence(first)]
                    + KMPState<Child>.asyncSequences(repeat each states),
                updatePolicy: updatePolicy,
                failurePolicy: failurePolicy
            )
        )
    }

    public mutating func update() {
        _storage.update()
        storage.rebind(
            to: parent,
            parentState: parentState,
            currentChild: currentChild
        )
    }
}
