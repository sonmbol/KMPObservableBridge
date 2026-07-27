import shared
import KMPObservableBridgeSKIE

// This app-only conformance gives SKIE StateFlow native Swift member access
// through KMPValueProperty. It is not part of the core or native product.
extension SkieSwiftStateFlow: @retroactive KMPValueProperty {}
