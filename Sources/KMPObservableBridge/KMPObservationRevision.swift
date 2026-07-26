#if canImport(Observation)
import Observation

/// The single Observation dependency token owned by a bridge store.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@Observable
@MainActor
final class KMPObservationRevision {
    var value: UInt = 0
}
#endif
