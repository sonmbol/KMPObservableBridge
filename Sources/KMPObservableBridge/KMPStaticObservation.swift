import Foundation

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

@MainActor
private final class KMPStaticObservationRegistry {
    static let shared = KMPStaticObservationRegistry()

    private final class WeakHub {
        weak var value: AnyObject?
    }

    private var hubs: [ObjectIdentifier: WeakHub] = [:]

    func observe<Model: AnyObject>(
        _ model: Model,
        plan: KMPObservationPlan<Model>,
        notify: @escaping KMPState<Model>.Notify,
        reportError: @escaping KMPState<Model>.ReportError
    ) -> KMPObservation {
        compactReleasedHubs()
        let key = ObjectIdentifier(model)
        let hub: KMPStaticObservationHub<Model>

        if let existing = hubs[key]?.value as? KMPStaticObservationHub<Model> {
            hub = existing
        } else {
            hub = KMPStaticObservationHub(model: model, plan: plan)
            let weakHub = WeakHub()
            weakHub.value = hub
            hubs[key] = weakHub
        }

        return hub.addListener(
            notify: notify,
            reportError: reportError
        )
    }

    private func compactReleasedHubs() {
        hubs = hubs.filter { $0.value.value != nil }
    }
}

@MainActor
private final class KMPStaticObservationHub<Model: AnyObject> {
    private struct Listener {
        let notify: KMPState<Model>.Notify
        let reportError: KMPState<Model>.ReportError
    }

    private let model: Model
    private let plan: KMPObservationPlan<Model>
    private var listeners: [UUID: Listener] = [:]
    private var observations: [KMPObservation] = []

    init(model: Model, plan: KMPObservationPlan<Model>) {
        self.model = model
        self.plan = plan
    }

    deinit {
        MainActor.assumeIsolated {
            observations.forEach { $0.cancel() }
        }
    }

    func addListener(
        notify: @escaping KMPState<Model>.Notify,
        reportError: @escaping KMPState<Model>.ReportError
    ) -> KMPObservation {
        let id = UUID()
        listeners[id] = Listener(
            notify: notify,
            reportError: reportError
        )
        if observations.isEmpty {
            start()
        }

        return KMPObservation { [self] in
            removeListener(id)
        }
    }

    private func start() {
        observations = plan.states.map { state in
            state.observe(
                model,
                { @MainActor [weak self] in
                    self?.listeners.values.forEach { $0.notify() }
                },
                { @MainActor [weak self] error in
                    self?.listeners.values.forEach {
                        $0.reportError(error)
                    }
                }
            )
        }
    }

    private func removeListener(_ id: UUID) {
        listeners.removeValue(forKey: id)
        guard listeners.isEmpty else {
            return
        }
        let current = observations
        observations.removeAll(keepingCapacity: false)
        current.forEach { $0.cancel() }
    }
}
