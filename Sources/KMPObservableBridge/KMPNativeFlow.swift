/// The structural function signature exported by KMP-NativeCoroutines.
public typealias KMPNativeFlow<Output, Failure: Error, Unit> = (
    _ onItem: @escaping (Output, @escaping () -> Unit, Unit) -> Unit,
    _ onComplete: @escaping (Failure?, Unit) -> Unit,
    _ onCancelled: @escaping (Failure, Unit) -> Unit
) -> () -> Unit

@MainActor
public protocol KMPNativeObservable: KMPStaticallyObservable {
    associatedtype KMPObservationOutput
    associatedtype KMPObservationFailure: Error
    associatedtype KMPObservationUnit

    var kmpObservationFlow: KMPNativeFlow<
        KMPObservationOutput,
        KMPObservationFailure,
        KMPObservationUnit
    > { get }
}
