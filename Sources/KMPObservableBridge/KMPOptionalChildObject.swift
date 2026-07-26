import SwiftUI

/// Observes an optional child ViewModel emitted by a parent state flow.
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
        _storage = StateObject(
            wrappedValue: KMPOptionalChildStore(
                parent: parent,
                parentState: .asyncSequence(child),
                currentChild: { parent[keyPath: child].value },
                childStates: [.asyncSequence(first)]
                    + KMPState<Child>.asyncSequences(repeat each states),
                updatePolicy: updatePolicy,
                failurePolicy: failurePolicy
            )
        )
    }
}
