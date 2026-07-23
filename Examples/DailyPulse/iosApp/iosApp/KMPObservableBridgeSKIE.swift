import shared
import KMPObservableBridge

/// SKIE emits this type through the generated Kotlin framework. The
/// conformance therefore belongs to the application target that can import
/// both the generated `shared` module and KMPObservableBridge.
extension SkieSwiftStateFlow: @retroactive KMPValueProperty {}
