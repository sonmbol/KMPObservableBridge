#if os(iOS) || os(macOS)
import SwiftUI
import XCTest
@testable import KMPObservableBridge

@MainActor
final class KMPObservableBridgeSwiftUIHostingTests: XCTestCase {
    func testObservationKeepsUnrelatedHostedSubtreeStable() async throws {
        let model = HostingModel()
        let probe = HostingRenderProbe()
        let firstMounted = expectation(description: "First field mounted")
        let secondMounted = expectation(description: "Second field mounted")
        probe.onNextRender(of: .first) {
            firstMounted.fulfill()
        }
        probe.onNextRender(of: .second) {
            secondMounted.fulfill()
        }

        let harness = AppleHostingHarness(
            rootView: HostingRoot(
                model: model,
                probe: probe,
                mode: .runtime
            )
        )
        await fulfillment(
            of: [firstMounted, secondMounted],
            timeout: 2
        )

        guard supportsFieldLevelObservation else {
            await removeContent(
                from: harness,
                assertingTeardownOf: model
            )
            throw XCTSkip(
                "Field isolation requires iOS 17+ or macOS 14+."
            )
        }

        XCTAssertEqual(model.first.startedCount, 1)
        XCTAssertEqual(model.second.startedCount, 1)
        XCTAssertEqual(model.global.startedCount, 1)
        let firstBaseline = probe.renderCount(for: .first)
        let secondBaseline = probe.renderCount(for: .second)
        let secondRendered = expectation(
            description: "Second field rerendered"
        )
        probe.onNextRender(of: .second) {
            secondRendered.fulfill()
        }

        model.second.emit(1)

        await fulfillment(of: [secondRendered], timeout: 2)
        await harness.flushPendingUpdates()
        XCTAssertEqual(
            probe.renderCount(for: .first),
            firstBaseline,
            "A field B emission must not reevaluate the A-only subtree."
        )
        XCTAssertGreaterThan(
            probe.renderCount(for: .second),
            secondBaseline
        )
        XCTAssertEqual(
            model.first.startedCount,
            1,
            "SwiftUI updates must preserve the mounted view identity."
        )
        XCTAssertEqual(model.second.startedCount, 1)
        XCTAssertEqual(model.global.startedCount, 1)

        await removeContent(
            from: harness,
            assertingTeardownOf: model
        )
    }

    func testGlobalInvalidationRerendersBothHostedSubtrees() async {
        let context = await makeMountedContext(mode: .runtime)
        let firstBaseline = context.probe.renderCount(for: .first)
        let secondBaseline = context.probe.renderCount(for: .second)
        let firstRendered = expectation(
            description: "First field globally invalidated"
        )
        let secondRendered = expectation(
            description: "Second field globally invalidated"
        )
        context.probe.onNextRender(of: .first) {
            firstRendered.fulfill()
        }
        context.probe.onNextRender(of: .second) {
            secondRendered.fulfill()
        }

        context.model.global.emit(1)

        await fulfillment(
            of: [firstRendered, secondRendered],
            timeout: 2
        )
        XCTAssertGreaterThan(
            context.probe.renderCount(for: .first),
            firstBaseline
        )
        XCTAssertGreaterThan(
            context.probe.renderCount(for: .second),
            secondBaseline
        )

        await removeContent(
            from: context.harness,
            assertingTeardownOf: context.model
        )
    }

    func testForcedObservableObjectFallbackRerendersBothHostedSubtrees() async {
        let context = await makeMountedContext(mode: .forcedFallback)
        let firstBaseline = context.probe.renderCount(for: .first)
        let secondBaseline = context.probe.renderCount(for: .second)
        let firstRendered = expectation(
            description: "Fallback rerendered first field"
        )
        let secondRendered = expectation(
            description: "Fallback rerendered second field"
        )
        context.probe.onNextRender(of: .first) {
            firstRendered.fulfill()
        }
        context.probe.onNextRender(of: .second) {
            secondRendered.fulfill()
        }

        context.model.second.emit(1)

        await fulfillment(
            of: [firstRendered, secondRendered],
            timeout: 2
        )
        XCTAssertGreaterThan(
            context.probe.renderCount(for: .first),
            firstBaseline,
            "The ObservableObject fallback intentionally invalidates globally."
        )
        XCTAssertGreaterThan(
            context.probe.renderCount(for: .second),
            secondBaseline
        )

        await removeContent(
            from: context.harness,
            assertingTeardownOf: context.model
        )
    }

    func testRuntimeFallbackRerendersBothHostedSubtrees() async throws {
        guard !supportsFieldLevelObservation else {
            throw XCTSkip(
                "Run this contract test on an iOS 15 or iOS 16 simulator."
            )
        }

        let context = await makeMountedContext(mode: .runtime)
        let firstBaseline = context.probe.renderCount(for: .first)
        let secondBaseline = context.probe.renderCount(for: .second)
        let firstRendered = expectation(
            description: "Runtime fallback rerendered first field"
        )
        let secondRendered = expectation(
            description: "Runtime fallback rerendered second field"
        )
        context.probe.onNextRender(of: .first) {
            firstRendered.fulfill()
        }
        context.probe.onNextRender(of: .second) {
            secondRendered.fulfill()
        }

        context.model.second.emit(1)

        await fulfillment(
            of: [firstRendered, secondRendered],
            timeout: 2
        )
        XCTAssertGreaterThan(
            context.probe.renderCount(for: .first),
            firstBaseline
        )
        XCTAssertGreaterThan(
            context.probe.renderCount(for: .second),
            secondBaseline
        )

        await removeContent(
            from: context.harness,
            assertingTeardownOf: context.model
        )
    }

    private var supportsFieldLevelObservation: Bool {
        if #available(iOS 17, macOS 14, *) {
            return true
        }
        return false
    }

    private func makeMountedContext(
        mode: HostingObservationMode
    ) async -> HostingContext {
        let model = HostingModel()
        let probe = HostingRenderProbe()
        let firstMounted = expectation(description: "First field mounted")
        let secondMounted = expectation(description: "Second field mounted")
        probe.onNextRender(of: .first) {
            firstMounted.fulfill()
        }
        probe.onNextRender(of: .second) {
            secondMounted.fulfill()
        }
        let harness = AppleHostingHarness(
            rootView: HostingRoot(
                model: model,
                probe: probe,
                mode: mode
            )
        )

        await fulfillment(
            of: [firstMounted, secondMounted],
            timeout: 2
        )
        return HostingContext(
            model: model,
            probe: probe,
            harness: harness
        )
    }

    private func removeContent(
        from harness: AppleHostingHarness,
        assertingTeardownOf model: HostingModel
    ) async {
        let observationsStopped = expectation(
            description: "All hosted observation sources stopped"
        )
        observationsStopped.expectedFulfillmentCount = 3
        model.first.onStop = {
            observationsStopped.fulfill()
        }
        model.second.onStop = {
            observationsStopped.fulfill()
        }
        model.global.onStop = {
            observationsStopped.fulfill()
        }

        harness.removeContent()

        await fulfillment(of: [observationsStopped], timeout: 2)
        for signal in [model.first, model.second, model.global] {
            XCTAssertEqual(signal.activeObserverCount, 0)
            XCTAssertEqual(signal.startedCount, 1)
            XCTAssertEqual(signal.stoppedCount, 1)
        }
    }
}
#endif
