import shared
import KMPObservableBridge

/// Models owned by `KMPStateObject` are disposed once with SwiftUI identity.
extension BaseViewModel: @retroactive KMPDisposable {
    public func dispose() {
        clear()
    }
}

extension BridgeCallbackState: @retroactive KMPValueProperty {}
