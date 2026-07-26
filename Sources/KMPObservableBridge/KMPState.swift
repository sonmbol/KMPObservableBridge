import Combine
import Foundation

/// Describes a state source whose emissions invalidate a SwiftUI view.
///
/// `KMPState` does not store emitted values. Kotlin remains the source of truth.
@MainActor
public struct KMPState<ViewModel: AnyObject> {
    public typealias Notify = KMPObservationNotify
    public typealias ReportError = KMPObservationErrorHandler
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

    /// Observes every emission without equality suppression.
    public static func everyEmission<Sequence: AsyncSequence>(
        _ keyPath: KeyPath<ViewModel, Sequence>
    ) -> Self {
        asyncSequence(keyPath)
    }

    /// Observes a sequence and suppresses consecutive equal elements.
    ///
    /// Generated static plans use this source by default. The first replay is
    /// always delivered so a state change racing initial view evaluation
    /// cannot be lost.
    public static func equatable<Sequence: AsyncSequence>(
        _ keyPath: KeyPath<ViewModel, Sequence>
    ) -> Self where Sequence.Element: Equatable {
        asyncSequence(keyPath, changes: { $0 })
    }

    /// Observes a sequence and invalidates only when a selected value changes.
    public static func asyncSequence<
        Sequence: AsyncSequence,
        Selection: Equatable
    >(
        _ keyPath: KeyPath<ViewModel, Sequence>,
        changes select: @escaping @MainActor (Sequence.Element) -> Selection
    ) -> Self {
        Self { viewModel, notify, reportError in
            let source = viewModel[keyPath: keyPath]
            let task = Task { @MainActor in
                var previous: Selection?
                var hasPrevious = false

                do {
                    for try await element in source {
                        try Task.checkCancellation()
                        let selection = select(element)
                        guard !hasPrevious || previous != selection else {
                            continue
                        }
                        previous = selection
                        hasPrevious = true
                        notify()
                    }
                } catch is CancellationError {
                    // Expected when SwiftUI destroys the identity store.
                } catch {
                    reportError(error)
                }
            }

            return KMPObservation {
                task.cancel()
            }
        }
    }

    /// Observes a sequence and invalidates only when its projection changes.
    public static func asyncSequence<
        Sequence: AsyncSequence,
        Selection: Equatable
    >(
        _ keyPath: KeyPath<ViewModel, Sequence>,
        changes: KMPChanges<Sequence.Element, Selection>
    ) -> Self {
        asyncSequence(keyPath, changes: changes.select)
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
                    Task { @MainActor in
                        notify()
                    }
                    _ = next()
                    return unit
                },
                { error, unit in
                    if let error {
                        Task { @MainActor in
                            reportError(error)
                        }
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
    /// The supplied callbacks are main-actor isolated. An adapter receiving a
    /// Kotlin callback on another thread must cross to `MainActor` once before
    /// invoking them.
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
                        Task { @MainActor in
                            reportError(error)
                        }
                    }
                },
                receiveValue: { _ in
                    Task { @MainActor in
                        notify()
                    }
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
    static var kmpObservationPlan: KMPObservationPlan<Self> {
        KMPObservationPlan(.automatic())
    }

    static func kmpStartObservation(
        on model: Self,
        notify: @escaping KMPObservationNotify,
        reportError: @escaping KMPObservationErrorHandler
    ) -> KMPObservation {
        kmpObservationPlan.startObservation(
            on: model,
            notify: notify,
            reportError: reportError
        )
    }
}
