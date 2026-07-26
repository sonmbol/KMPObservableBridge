/// Optional lifecycle contract for ViewModels owned by `KMPStateObject`.
///
/// Externally owned and environment-provided models are never disposed by the
/// bridge.
@MainActor
public protocol KMPDisposable: AnyObject {
    func dispose()
}
