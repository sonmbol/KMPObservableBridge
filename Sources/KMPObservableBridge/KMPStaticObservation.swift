/// A KMP model whose observation sources were verified by the Swift compiler.
///
/// Conformances are normally expanded by `#KMPObservable` after importing the
/// Kotlin framework. Applications can also write one manually.
@MainActor
public protocol KMPStaticallyObservable: AnyObject {
    static func kmpStartObservation(
        on model: Self,
        notify: @escaping KMPObservationNotify,
        reportError: @escaping KMPObservationErrorHandler
    ) -> KMPObservation
}

/// A compile-time-checked collection of observation sources for one model.
@MainActor
public struct KMPObservationPlan<Model: AnyObject> {
    let states: [KMPState<Model>]

    public init(_ states: KMPState<Model>...) {
        self.states = states
    }

    func observe(
        _ model: Model,
        notify: @escaping KMPState<Model>.Notify,
        reportError: @escaping KMPState<Model>.ReportError
    ) -> KMPObservation {
        KMPStaticObservationRegistry.shared.observe(
            model,
            plan: self,
            notify: notify,
            reportError: reportError
        )
    }

    /// Starts the plan through the shared per-model observation hub.
    public func startObservation(
        on model: Model,
        notify: @escaping KMPState<Model>.Notify,
        reportError: @escaping KMPState<Model>.ReportError
    ) -> KMPObservation {
        observe(model, notify: notify, reportError: reportError)
    }
}
