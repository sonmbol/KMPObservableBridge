/// Fuses a field's SwiftUI dependency cell with its optional demand lease.
@MainActor
final class KMPFieldObservationSlot {
    var revision: AnyObject?
    private var observation: KMPObservation?

    func activate(_ makeObservation: () -> KMPObservation) {
        guard observation == nil else {
            return
        }
        observation = makeObservation()
    }

    func cancel() {
        observation?.cancel()
        observation = nil
    }

    deinit {
        MainActor.assumeIsolated {
            observation?.cancel()
        }
    }
}
