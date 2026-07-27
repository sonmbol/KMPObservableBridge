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
