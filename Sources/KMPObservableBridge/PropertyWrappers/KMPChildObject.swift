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

    public init<First: AsyncSequence, each Sequence: AsyncSequence>(
        parent: Parent,
        child: KeyPath<Parent, Child>,
        states first: KeyPath<Child, First>,
        _ states: repeat KeyPath<Child, each Sequence>,
        updatePolicy: KMPUpdatePolicy = .coalesced,
        failurePolicy: KMPObservationFailurePolicy = .log
    ) {
        let sources = [.asyncSequence(first)]
            + KMPState<Child>.asyncSequences(repeat each states)
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
