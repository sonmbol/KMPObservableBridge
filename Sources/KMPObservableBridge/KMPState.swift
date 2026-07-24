import Combine
import Foundation
import SwiftUI

/// The structural function signature exported by KMP-NativeCoroutines as
/// `NativeFlow`.
///
/// Defining the signature locally lets the bridge observe NativeCoroutines
/// without making it a required package dependency.
public typealias KMPNativeFlow<Output, Failure: Error, Unit> = (
    _ onItem: @escaping (Output, @escaping () -> Unit, Unit) -> Unit,
    _ onComplete: @escaping (Failure?, Unit) -> Unit,
    _ onCancelled: @escaping (Failure, Unit) -> Unit
) -> () -> Unit

/// Opt-in automatic observation for a Kotlin model that exposes one canonical
/// KMP-NativeCoroutines invalidation flow.
///
/// The flow's elements are not cached by Swift. They only tell SwiftUI that the
/// model's Kotlin-owned properties should be read again.
@MainActor
public protocol KMPAutomaticallyObservable: AnyObject {
    func kmpObserveAutomatically(
        notify: @escaping @Sendable () -> Void,
        reportError: @escaping @Sendable (Error) -> Void
    ) -> KMPObservation
}

@MainActor
public protocol KMPNativeObservable: KMPAutomaticallyObservable {
    associatedtype KMPObservationOutput
    associatedtype KMPObservationFailure: Error
    associatedtype KMPObservationUnit

    var kmpObservationFlow: KMPNativeFlow<
        KMPObservationOutput,
        KMPObservationFailure,
        KMPObservationUnit
    > { get }
}

/// A KMP wrapper that exposes its current value through a `value` property.
///
/// Conformance only provides dynamic-member syntax for nested reads. The
/// bridge never copies, flattens, or owns the Kotlin value.
@dynamicMemberLookup
public protocol KMPValueProperty {
    associatedtype Value

    var value: Value { get }
}

public extension KMPValueProperty {
    subscript<Member>(dynamicMember keyPath: KeyPath<Value, Member>) -> Member {
        value[keyPath: keyPath]
    }
}

public extension Text {
    /// Creates text from a scalar string held by a KMP value property.
    ///
    /// This complements dynamic-member lookup, which only applies when the
    /// emitted value has a nested member such as `state.isLoading`.
    init<Property>(_ property: Property)
    where Property: KMPValueProperty, Property.Value == String {
        self.init(verbatim: property.value)
    }
}

/// A main-actor cancellation token for a single KMP observation.
///
/// Cancellation is idempotent and is also performed when the token is released.
@MainActor
public final class KMPObservation {
    private var onCancel: (() -> Void)?

    public init(_ onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    public func cancel() {
        let action = onCancel
        onCancel = nil
        action?()
    }

    deinit {
        MainActor.assumeIsolated {
            onCancel?()
        }
    }

    public static var empty: KMPObservation {
        KMPObservation {}
    }

    /// Combines observations into one idempotent lifecycle handle.
    public static func group(_ observations: KMPObservation...) -> KMPObservation {
        KMPObservation {
            observations.forEach { $0.cancel() }
        }
    }
}

public extension KMPObservation {
    convenience init(_ cancellable: AnyCancellable) {
        self.init {
            cancellable.cancel()
        }
    }
}

/// Describes a state source whose emissions invalidate a SwiftUI view.
///
/// `KMPState` does not store emitted values. Kotlin remains the source of truth.
@MainActor
public struct KMPState<ViewModel: AnyObject> {
    public typealias Notify = @Sendable () -> Void
    public typealias ReportError = @Sendable (Error) -> Void
    typealias Observer = @MainActor (
        ViewModel,
        @escaping Notify,
        @escaping ReportError
    ) -> KMPObservation

    let observe: Observer

    /// Starts this state adapter outside a wrapper.
    ///
    /// This is primarily used by build-time generated model conformances.
    public func startObservation(
        on viewModel: ViewModel,
        notify: @escaping Notify,
        reportError: @escaping ReportError
    ) -> KMPObservation {
        observe(viewModel, notify, reportError)
    }

    private init(observe: @escaping Observer) {
        self.observe = observe
    }

    static func asyncSequences<each Sequence: AsyncSequence>(
        _ keyPaths: repeat KeyPath<ViewModel, each Sequence>
    ) -> [Self] {
        var result: [Self] = []
        for keyPath in repeat each keyPaths {
            result.append(.asyncSequence(keyPath))
        }
        return result
    }

    /// Observes an `AsyncSequence` property, including a SKIE StateFlow.
    public static func asyncSequence<Sequence: AsyncSequence>(
        _ keyPath: KeyPath<ViewModel, Sequence>
    ) -> Self {
        asyncSequence { $0[keyPath: keyPath] }
    }

    /// Observes a KMP-NativeCoroutines `NativeFlow` directly.
    ///
    /// Items trigger view invalidation, completion errors use the configured
    /// failure policy, and lifecycle cancellation is propagated to Kotlin.
    public static func nativeFlow<Output, Failure: Error, Unit>(
        _ keyPath: KeyPath<
            ViewModel,
            KMPNativeFlow<Output, Failure, Unit>
        >
    ) -> Self {
        Self { viewModel, notify, reportError in
            let flow = viewModel[keyPath: keyPath]
            let cancel = flow(
                { _, next, unit in
                    notify()
                    _ = next()
                    return unit
                },
                { error, unit in
                    if let error {
                        reportError(error)
                    }
                    return unit
                },
                { _, unit in
                    // Kotlin cancellation is an expected lifecycle event.
                    return unit
                }
            )

            return KMPObservation {
                _ = cancel()
            }
        }
    }

    /// Uses the canonical flow supplied by an opt-in observable model.
    public static func automatic() -> Self
    where ViewModel: KMPNativeObservable {
        .nativeFlow(\.kmpObservationFlow)
    }

    /// Observes an `AsyncSequence` produced by an interoperability adapter.
    public static func asyncSequence<Sequence: AsyncSequence>(
        _ sequence: @escaping @MainActor (ViewModel) -> Sequence
    ) -> Self {
        Self { viewModel, notify, reportError in
            let source = sequence(viewModel)
            let task = Task { @MainActor in
                do {
                    for try await _ in source {
                        try Task.checkCancellation()
                        notify()
                    }
                } catch is CancellationError {
                    // Cancellation is an expected lifecycle event.
                } catch {
                    reportError(error)
                }
            }

            return KMPObservation {
                task.cancel()
            }
        }
    }

    /// Observes a callback-style KMP API.
    ///
    /// `notify` and `reportError` may be called from any thread. The bridge
    /// marshals delivery to the main actor and suppresses stale observations.
    public static func callback(
        _ observe: @escaping @MainActor (
            ViewModel,
            @escaping Notify,
            @escaping ReportError
        ) -> KMPObservation
    ) -> Self {
        Self(observe: observe)
    }

    /// Observes a Combine publisher derived from the KMP model.
    public static func publisher<PublisherType: Publisher>(
        _ publisher: @escaping @MainActor (ViewModel) -> PublisherType
    ) -> Self {
        Self { viewModel, notify, reportError in
            let cancellable = publisher(viewModel).sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        reportError(error)
                    }
                },
                receiveValue: { _ in
                    notify()
                }
            )

            return KMPObservation(cancellable)
        }
    }

    /// Builds a custom observation for advanced interoperability adapters.
    public static func custom(
        _ observe: @escaping @MainActor (
            ViewModel,
            @escaping Notify,
            @escaping ReportError
        ) -> KMPObservation
    ) -> Self {
        Self(observe: observe)
    }
}

public extension KMPNativeObservable {
    @MainActor
    func kmpObserveAutomatically(
        notify: @escaping KMPState<Self>.Notify,
        reportError: @escaping KMPState<Self>.ReportError
    ) -> KMPObservation {
        KMPState<Self>.automatic().startObservation(
            on: self,
            notify: notify,
            reportError: reportError
        )
    }
}
