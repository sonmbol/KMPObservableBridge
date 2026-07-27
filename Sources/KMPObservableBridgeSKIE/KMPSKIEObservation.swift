@_exported import KMPObservableBridge

/// Marks a statically declared observation route as SKIE-backed.
///
/// This API intentionally mentions no concrete SKIE runtime type. The concrete
/// `SkieSwiftStateFlow` lives in the consuming KMP framework, so an application
/// macro supplies an ordinary, compiler-checked key path.
public extension KMPState {
    /// Observes a SKIE `StateFlow` and suppresses consecutive equal values.
    static func skie<Sequence: AsyncSequence>(
        _ keyPath: KeyPath<ViewModel, Sequence>
    ) -> Self where Sequence.Element: Equatable {
        .equatable(keyPath)
    }

    /// Observes every SKIE `Flow` emission.
    ///
    /// Use this for event streams or non-`Equatable` element types.
    static func skieEveryEmission<Sequence: AsyncSequence>(
        _ keyPath: KeyPath<ViewModel, Sequence>
    ) -> Self {
        .everyEmission(keyPath)
    }
}
