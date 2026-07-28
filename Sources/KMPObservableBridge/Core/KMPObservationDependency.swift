/// Identifies the SwiftUI dependency affected by an observation emission.
///
/// This is intentionally internal. Public adapters continue to notify through
/// their existing parameterless callbacks.
enum KMPObservationDependency: Hashable {
    case global
    case field(AnyKeyPath)
}

typealias KMPDependencyNotify =
    @MainActor @Sendable (KMPObservationDependency) -> Void

/// A keyed change callback used by statically observable models.
///
/// `nil` represents a global change. A key path represents one field.
public typealias KMPObservationDependencyNotify =
    @MainActor @Sendable (AnyKeyPath?) -> Void
