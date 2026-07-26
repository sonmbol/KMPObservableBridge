@_exported import KMPObservableBridge

/// Namespace exported by the native integration product.
///
/// Importing `KMPObservableBridgeNative` exposes the structural NativeFlow
/// adapters from the core bridge but never imports or declares SKIE symbols.
public enum KMPNativeObservationIntegration: Sendable {
    public static let isAvailable = true
}
