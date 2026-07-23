import Combine
import Foundation

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
