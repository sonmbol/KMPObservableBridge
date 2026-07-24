import Foundation

/// Selects an optional automatic interoperability mechanism.
public enum KMPAutomaticObservation {
    /// Lazily discovers SKIE StateFlows through their Objective-C getters.
    ///
    /// This is an experimental compatibility mode because it relies on
    /// Objective-C method interception and SKIE's generated iterator ABI.
    /// Prefer explicit `state:` or `states:` key paths for maximum stability.
    case automaticSKIE
}
import OSLog

/// Controls how frequently state emissions invalidate SwiftUI.
public enum KMPUpdatePolicy: Sendable {
    /// Coalesces emissions queued in the same main-actor turn.
    case coalesced
    /// Delivers one invalidation for every emission.
    case immediate
}

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
            ).error("Observation failed: \(String(describing: error), privacy: .public)")
        case .ignore:
            break
        case .custom(let handler):
            handler(error)
        }
    }
}

/// Optional lifecycle contract for ViewModels owned by `KMPStateObject`.
///
/// Generated Kotlin base classes can adopt this protocol retroactively in the
/// iOS target. Externally owned and environment-provided models are never
/// disposed by the bridge.
@MainActor
public protocol KMPDisposable: AnyObject {
    func dispose()
}
