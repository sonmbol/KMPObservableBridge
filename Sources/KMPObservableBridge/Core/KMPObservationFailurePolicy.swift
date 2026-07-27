import OSLog

/// Controls failures in the observation mechanism.
///
/// Domain failures belong in Kotlin screen state, not in this policy.
public enum KMPObservationFailurePolicy {
    /// Writes a non-fatal diagnostic to the system log.
    case log

    /// Deliberately ignores observation failures.
    case ignore

    /// Delivers failures to a main-actor handler.
    case custom(@MainActor (Error) -> Void)

    @MainActor
    func report(_ error: Error) {
        switch self {
        case .log:
            Logger(
                subsystem: "KMPObservableBridge",
                category: "Observation"
            ).error(
                "Observation failed: \(String(describing: error), privacy: .public)"
            )
        case .ignore:
            break
        case .custom(let handler):
            handler(error)
        }
    }
}
