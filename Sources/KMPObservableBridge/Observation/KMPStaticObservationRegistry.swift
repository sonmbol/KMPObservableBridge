@MainActor
final class KMPStaticObservationRegistry {
    static let shared = KMPStaticObservationRegistry()

    private final class WeakHub {
        weak var value: AnyObject?
    }

    private var hubs: [ObjectIdentifier: WeakHub] = [:]

    private init() {}

    func observe<Model: AnyObject>(
        _ model: Model,
        plan: KMPObservationPlan<Model>,
        notify: @escaping KMPDependencyNotify,
        reportError: @escaping KMPState<Model>.ReportError
    ) -> KMPObservation {
        let key = ObjectIdentifier(model)
        let hub: KMPStaticObservationHub<Model>

        if let existing = hubs[key]?.value as? KMPStaticObservationHub<Model> {
            hub = existing
        } else {
            hub = KMPStaticObservationHub(
                model: model,
                plan: plan,
                registryKey: key
            )
            let weakHub = WeakHub()
            weakHub.value = hub
            hubs[key] = weakHub
        }

        return hub.addListener(
            notify: notify,
            reportError: reportError
        )
    }

    func removeHub(
        for key: ObjectIdentifier,
        matching hub: AnyObject
    ) {
        guard hubs[key]?.value === hub else {
            return
        }
        hubs.removeValue(forKey: key)
    }
}
