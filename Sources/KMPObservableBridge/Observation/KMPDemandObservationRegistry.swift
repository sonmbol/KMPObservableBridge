/// Shares lazily activated field collectors between every store for a model.
@MainActor
final class KMPDemandObservationRegistry {
    static let shared = KMPDemandObservationRegistry()

    private final class WeakHub {
        weak var value: AnyObject?
    }

    private var hubs: [ObjectIdentifier: WeakHub] = [:]

    private init() {}

    func observe<Model: AnyObject>(
        _ model: Model,
        state: KMPState<Model>,
        notify: @escaping KMPObservationNotify,
        reportError: @escaping KMPObservationErrorHandler
    ) -> KMPObservation {
        let identity = ObjectIdentifier(model)
        let hub: KMPDemandObservationHub<Model>

        if let existing = hubs[identity]?.value as? KMPDemandObservationHub<Model> {
            hub = existing
        } else {
            hub = KMPDemandObservationHub(
                model: model,
                registryKey: identity
            )
            let weakHub = WeakHub()
            weakHub.value = hub
            hubs[identity] = weakHub
        }

        return hub.addListener(
            for: state,
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
