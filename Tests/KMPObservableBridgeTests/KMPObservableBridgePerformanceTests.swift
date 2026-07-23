import Combine
import XCTest
@testable import KMPObservableBridge

@MainActor
final class KMPObservableBridgePerformanceTests: XCTestCase {
    private final class Model {
        let state = PassthroughSubject<Int, Never>()
    }

    func testTenThousandImmediateEmissions() {
        let model = Model()
        let store = KMPViewModelStore(
            model,
            states: [.publisher(\.state)],
            updatePolicy: .immediate,
            failurePolicy: .ignore,
            ownsModel: false,
            modernObservationEnabled: false
        )
        let cancellable = store.objectWillChange.sink {}

        measure {
            for value in 0..<10_000 {
                model.state.send(value)
            }
        }

        withExtendedLifetime(cancellable) {}
    }

    func testStoreCreationAndTeardown() {
        measure {
            for _ in 0..<1_000 {
                autoreleasepool {
                    let model = Model()
                    _ = KMPViewModelStore(
                        model,
                        states: [.publisher(\.state)],
                        updatePolicy: .coalesced,
                        failurePolicy: .ignore,
                        ownsModel: false,
                        modernObservationEnabled: false
                    )
                }
            }
        }
    }
}
