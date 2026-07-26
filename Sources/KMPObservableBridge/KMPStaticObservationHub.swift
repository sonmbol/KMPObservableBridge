/// Shares one set of Kotlin collectors between all stores observing a model.
@MainActor
final class KMPStaticObservationHub<Model: AnyObject> {
    private struct Listener {
        let notify: KMPState<Model>.Notify
        let reportError: KMPState<Model>.ReportError
    }

    private let model: Model
    private let plan: KMPObservationPlan<Model>
    private let registryKey: ObjectIdentifier
    private var listeners: [UInt: Listener] = [:]
    private var observations: [KMPObservation] = []
    private var nextListenerID: UInt = 0
    private var broadcastDepth = 0
    private var pendingRemovals: Set<UInt>?

    init(
        model: Model,
        plan: KMPObservationPlan<Model>,
        registryKey: ObjectIdentifier
    ) {
        self.model = model
        self.plan = plan
        self.registryKey = registryKey
    }

    deinit {
        MainActor.assumeIsolated {
            observations.forEach { $0.cancel() }
            KMPStaticObservationRegistry.shared.removeHub(
                for: registryKey,
                matching: self
            )
        }
    }

    func addListener(
        notify: @escaping KMPState<Model>.Notify,
        reportError: @escaping KMPState<Model>.ReportError
    ) -> KMPObservation {
        let id = makeListenerID()
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

    private func makeListenerID() -> UInt {
        repeat {
            nextListenerID &+= 1
        } while listeners[nextListenerID] != nil
        return nextListenerID
    }

    private func start() {
        observations = plan.states.map { state in
            state.observe(
                model,
                { @MainActor [weak self] in
                    self?.broadcastNotification()
                },
                { @MainActor [weak self] error in
                    self?.broadcast(error)
                }
            )
        }
    }

    private func broadcastNotification() {
        withBroadcast {
            for listener in listeners.values {
                listener.notify()
            }
        }
    }

    private func broadcast(_ error: Error) {
        withBroadcast {
            for listener in listeners.values {
                listener.reportError(error)
            }
        }
    }

    private func withBroadcast(_ body: () -> Void) {
        broadcastDepth += 1
        body()
        broadcastDepth -= 1

        guard broadcastDepth == 0, let pendingRemovals else {
            return
        }
        self.pendingRemovals = nil
        for id in pendingRemovals {
            listeners.removeValue(forKey: id)
        }
        stopIfUnobserved()
    }

    private func removeListener(_ id: UInt) {
        guard broadcastDepth == 0 else {
            if pendingRemovals == nil {
                pendingRemovals = []
            }
            pendingRemovals?.insert(id)
            return
        }
        listeners.removeValue(forKey: id)
        stopIfUnobserved()
    }

    private func stopIfUnobserved() {
        guard listeners.isEmpty else {
            return
        }
        let current = observations
        observations.removeAll(keepingCapacity: false)
        current.forEach { $0.cancel() }
    }
}
