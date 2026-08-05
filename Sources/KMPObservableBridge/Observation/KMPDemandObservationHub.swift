/// Owns one collector for every field demanded by at least one store.
@MainActor
final class KMPDemandObservationHub<Model: AnyObject> {
    private struct Listener {
        let notify: KMPObservationNotify
        let reportError: KMPObservationErrorHandler
    }

    private final class Field {
        var listeners: [UInt: Listener] = [:]
        var observation: KMPObservation?
        var broadcastDepth = 0
        var pendingAdditions: [UInt: Listener]?
        var pendingRemovals: Set<UInt>?
    }

    private let model: Model
    private let registryKey: ObjectIdentifier
    private var fields: [AnyKeyPath: Field] = [:]
    private var nextListenerID: UInt = 0

    init(model: Model, registryKey: ObjectIdentifier) {
        self.model = model
        self.registryKey = registryKey
    }

    deinit {
        MainActor.assumeIsolated {
            fields.values.forEach { $0.observation?.cancel() }
            KMPDemandObservationRegistry.shared.removeHub(
                for: registryKey,
                matching: self
            )
        }
    }

    func addListener(
        for state: KMPState<Model>,
        notify: @escaping KMPObservationNotify,
        reportError: @escaping KMPObservationErrorHandler
    ) -> KMPObservation {
        guard case .field(let keyPath) = state.dependency else {
            return state.startObservation(
                on: model,
                notify: notify,
                reportError: reportError
            )
        }

        let field = fields[keyPath] ?? {
            let field = Field()
            fields[keyPath] = field
            return field
        }()
        let listenerID = makeListenerID(for: field)
        let listener = Listener(
            notify: notify,
            reportError: reportError
        )
        if field.broadcastDepth == 0 {
            field.listeners[listenerID] = listener
        } else {
            if field.pendingAdditions == nil {
                field.pendingAdditions = [:]
            }
            field.pendingAdditions?[listenerID] = listener
        }

        if field.observation == nil {
            field.observation = state.startObservation(
                on: model,
                notify: { @MainActor [weak self] in
                    self?.broadcastChange(for: keyPath)
                },
                reportError: { @MainActor [weak self] error in
                    self?.broadcast(error, for: keyPath)
                }
            )
        }

        return KMPObservation { [self] in
            removeListener(listenerID, for: keyPath)
        }
    }

    private func makeListenerID(for field: Field) -> UInt {
        repeat {
            nextListenerID &+= 1
        } while field.listeners[nextListenerID] != nil ||
            field.pendingAdditions?[nextListenerID] != nil
        return nextListenerID
    }

    private func broadcastChange(for keyPath: AnyKeyPath) {
        broadcast(for: keyPath) { $0.notify() }
    }

    private func broadcast(_ error: Error, for keyPath: AnyKeyPath) {
        broadcast(for: keyPath) { $0.reportError(error) }
    }

    private func broadcast(
        for keyPath: AnyKeyPath,
        _ action: (Listener) -> Void
    ) {
        guard let field = fields[keyPath] else {
            return
        }
        field.broadcastDepth += 1
        for listener in field.listeners.values {
            action(listener)
        }
        field.broadcastDepth -= 1

        guard field.broadcastDepth == 0 else {
            return
        }
        if let additions = field.pendingAdditions {
            field.pendingAdditions = nil
            for (id, listener) in additions {
                field.listeners[id] = listener
            }
        }
        guard let removals = field.pendingRemovals else {
            return
        }
        field.pendingRemovals = nil
        removals.forEach { field.listeners.removeValue(forKey: $0) }
        stopFieldIfUnobserved(field, keyPath: keyPath)
    }

    private func removeListener(_ id: UInt, for keyPath: AnyKeyPath) {
        guard let field = fields[keyPath] else {
            return
        }
        guard field.broadcastDepth == 0 else {
            if field.pendingRemovals == nil {
                field.pendingRemovals = []
            }
            field.pendingRemovals?.insert(id)
            return
        }
        field.listeners.removeValue(forKey: id)
        stopFieldIfUnobserved(field, keyPath: keyPath)
    }

    private func stopFieldIfUnobserved(
        _ field: Field,
        keyPath: AnyKeyPath
    ) {
        guard field.listeners.isEmpty else {
            return
        }
        field.observation?.cancel()
        field.observation = nil
        fields.removeValue(forKey: keyPath)
    }
}
