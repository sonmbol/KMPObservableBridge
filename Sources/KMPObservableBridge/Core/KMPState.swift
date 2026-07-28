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
    let dependency: KMPObservationDependency

    /// Starts this state adapter outside a wrapper.
    ///
    /// This is primarily used by macro-expanded model conformances.
    public func startObservation(
        on viewModel: ViewModel,
        notify: @escaping Notify,
        reportError: @escaping ReportError
    ) -> KMPObservation {
        observe(viewModel, notify, reportError)
    }

    init(
        dependency: KMPObservationDependency = .global,
        observe: @escaping Observer
    ) {
        self.dependency = dependency
        self.observe = observe
    }
}
