/// A KMP model whose observation sources were verified by the Swift compiler.
///
/// Conformances are normally expanded by `#KMPObservable` after importing the
/// Kotlin framework. Applications can also write one manually.
@MainActor
public protocol KMPStaticallyObservable: AnyObject {
    static var kmpObservationStrategy: KMPObservationStrategy { get }

    static func kmpStartObservation(
        on model: Self,
        notify: @escaping KMPObservationNotify,
        reportError: @escaping KMPObservationErrorHandler
    ) -> KMPObservation

    static func kmpStartObservation(
        on model: Self,
        notifyDependency: @escaping KMPObservationDependencyNotify,
        reportError: @escaping KMPObservationErrorHandler
    ) -> KMPObservation
}

public extension KMPStaticallyObservable {
    static var kmpObservationStrategy: KMPObservationStrategy {
        .explicit
    }

    /// Compatibility route for manually implemented 1.1 conformances.
    static func kmpStartObservation(
        on model: Self,
        notifyDependency: @escaping KMPObservationDependencyNotify,
        reportError: @escaping KMPObservationErrorHandler
    ) -> KMPObservation {
        kmpStartObservation(
            on: model,
            notify: { notifyDependency(nil) },
            reportError: reportError
        )
    }
}

/// Selects when a statically observable model starts its field collectors.
public enum KMPObservationStrategy: Sendable {
    /// Starts the compiler-checked plan when the wrapper is realized.
    case explicit

    /// Starts each supported field when its projected value is first read.
    case demandDriven
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
        notify: @escaping KMPDependencyNotify,
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
        observe(
            model,
            notify: { _ in notify() },
            reportError: reportError
        )
    }

    /// Starts the plan while retaining its field dependency keys.
    public func observeDependencies(
        on model: Model,
        notifyDependency: @escaping KMPObservationDependencyNotify,
        reportError: @escaping KMPObservationErrorHandler
    ) -> KMPObservation {
        observe(
            model,
            notify: { dependency in
                switch dependency {
                case .global:
                    notifyDependency(nil)
                case .field(let keyPath):
                    notifyDependency(keyPath)
                }
            },
            reportError: reportError
        )
    }
}
