import Combine

public typealias KMPObservationNotify = @MainActor @Sendable () -> Void
public typealias KMPObservationErrorHandler =
    @MainActor @Sendable (Error) -> Void

/// An idempotent, main-actor cancellation handle.
///
/// Releasing the last handle deterministically tears down its Kotlin, Combine,
/// callback, or task-backed observation.
@MainActor
public final class KMPObservation {
    private var cancellation: (() -> Void)?

    public init(_ cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    public convenience init(_ cancellable: AnyCancellable) {
        self.init {
            cancellable.cancel()
        }
    }

    public func cancel() {
        let action = cancellation
        cancellation = nil
        action?()
    }

    deinit {
        MainActor.assumeIsolated {
            cancellation?()
        }
    }

    public static var empty: KMPObservation {
        KMPObservation {}
    }

    public static func group(
        _ observations: KMPObservation...
    ) -> KMPObservation {
        KMPObservation {
            observations.forEach { $0.cancel() }
        }
    }
}
