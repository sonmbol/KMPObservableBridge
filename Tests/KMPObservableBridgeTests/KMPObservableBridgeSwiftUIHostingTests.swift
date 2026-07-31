#if os(iOS) || os(macOS)
import SwiftUI
import XCTest
@testable import KMPObservableBridge

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

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
            harness.removeContent()
            throw XCTSkip(
                "Field isolation requires iOS 17 or macOS 14."
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

@MainActor
private struct HostingContext {
    let model: HostingModel
    let probe: HostingRenderProbe
    let harness: AppleHostingHarness
}

private enum HostedField: Hashable {
    case first
    case second
}

private enum HostingObservationMode {
    case runtime
    case forcedFallback
}

@MainActor
private final class HostingRenderProbe {
    private var counts: [HostedField: Int] = [:]
    private var nextRender: [HostedField: () -> Void] = [:]

    func renderCount(for field: HostedField) -> Int {
        counts[field, default: 0]
    }

    func onNextRender(
        of field: HostedField,
        perform action: @escaping () -> Void
    ) {
        precondition(nextRender[field] == nil)
        nextRender[field] = action
    }

    func record(_ field: HostedField, value: Int) -> String {
        counts[field, default: 0] += 1
        let action = nextRender.removeValue(forKey: field)
        action?()
        return "\(value)"
    }
}

private final class HostingSignal:
    KMPValueProperty,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var currentValue: Int
    @MainActor private var observers: [UInt: KMPObservationNotify] = [:]
    @MainActor private var nextObserverID: UInt = 0
    @MainActor private(set) var startedCount = 0
    @MainActor private(set) var stoppedCount = 0
    @MainActor var onStop: (() -> Void)?

    var value: Int {
        lock.withLock {
            currentValue
        }
    }

    @MainActor
    var activeObserverCount: Int {
        observers.count
    }

    init(_ value: Int) {
        currentValue = value
    }

    @MainActor
    func observe(
        _ notify: @escaping KMPObservationNotify
    ) -> KMPObservation {
        nextObserverID &+= 1
        let observerID = nextObserverID
        observers[observerID] = notify
        startedCount += 1

        return KMPObservation { [weak self] in
            MainActor.assumeIsolated {
                self?.removeObserver(observerID)
            }
        }
    }

    @MainActor
    func emit(_ value: Int) {
        lock.withLock {
            currentValue = value
        }
        let callbacks = Array(observers.values)
        callbacks.forEach { $0() }
    }

    @MainActor
    private func removeObserver(_ observerID: UInt) {
        guard observers.removeValue(forKey: observerID) != nil else {
            return
        }
        stoppedCount += 1
        onStop?()
    }
}

@MainActor
private final class HostingModel: KMPStaticallyObservable {
    let first = HostingSignal(0)
    let second = HostingSignal(0)
    let global = HostingSignal(0)

    static var kmpObservationPlan: KMPObservationPlan<HostingModel> {
        KMPObservationPlan(
            KMPState(dependency: .field(\HostingModel.first)) {
                model, notify, _ in
                model.first.observe(notify)
            },
            KMPState(dependency: .field(\HostingModel.second)) {
                model, notify, _ in
                model.second.observe(notify)
            },
            KMPState(dependency: .global) { model, notify, _ in
                model.global.observe(notify)
            }
        )
    }

    static func kmpStartObservation(
        on model: HostingModel,
        notify: @escaping KMPObservationNotify,
        reportError: @escaping KMPObservationErrorHandler
    ) -> KMPObservation {
        kmpObservationPlan.startObservation(
            on: model,
            notify: notify,
            reportError: reportError
        )
    }

    static func kmpStartObservation(
        on model: HostingModel,
        notifyDependency: @escaping KMPObservationDependencyNotify,
        reportError: @escaping KMPObservationErrorHandler
    ) -> KMPObservation {
        kmpObservationPlan.observeDependencies(
            on: model,
            notifyDependency: notifyDependency,
            reportError: reportError
        )
    }
}

@MainActor
private struct HostingRoot: View {
    let model: HostingModel
    let probe: HostingRenderProbe
    let mode: HostingObservationMode

    var body: some View {
        VStack {
            field(.first)
            field(.second)
        }
    }

    @ViewBuilder
    private func field(_ field: HostedField) -> some View {
        switch mode {
        case .runtime:
            HostedProjectedField(
                model: model,
                field: field,
                probe: probe
            )
        case .forcedFallback:
            FallbackHostedProjectedField(
                model: model,
                field: field,
                probe: probe
            )
        }
    }
}

@MainActor
private struct HostedProjectedField: View {
    @KMPObservedObject private var model: HostingModel
    let field: HostedField
    let probe: HostingRenderProbe

    init(
        model: HostingModel,
        field: HostedField,
        probe: HostingRenderProbe
    ) {
        _model = KMPObservedObject(
            model,
            updatePolicy: .immediate,
            failurePolicy: .ignore
        )
        self.field = field
        self.probe = probe
    }

    var body: some View {
        let value: Int
        switch field {
        case .first:
            value = $model.first
        case .second:
            value = $model.second
        }
        return Text(verbatim: probe.record(field, value: value))
    }
}

@MainActor
private struct FallbackHostedProjectedField: View {
    @StateObject private var storage: KMPViewModelStore<HostingModel>
    let field: HostedField
    let probe: HostingRenderProbe

    init(
        model: HostingModel,
        field: HostedField,
        probe: HostingRenderProbe
    ) {
        _storage = StateObject(
            wrappedValue: KMPViewModelStore(
                model,
                source: .staticPlan(HostingModel.kmpObservationPlan),
                updatePolicy: .immediate,
                failurePolicy: .ignore,
                ownsModel: false,
                modernObservationEnabled: false
            )
        )
        self.field = field
        self.probe = probe
    }

    var body: some View {
        let value: Int
        switch field {
        case .first:
            value = storage.first
        case .second:
            value = storage.second
        }
        return Text(verbatim: probe.record(field, value: value))
    }
}

@MainActor
private final class AppleHostingHarness {
    #if os(iOS)
    private let window: UIWindow
    private let controller: UIHostingController<AnyView>
    #elseif os(macOS)
    private let window: NSWindow
    private let controller: NSHostingController<AnyView>
    #endif

    init<Content: View>(rootView: Content) {
        #if os(iOS)
        controller = UIHostingController(rootView: AnyView(rootView))
        window = UIWindow(
            frame: CGRect(x: 0, y: 0, width: 320, height: 480)
        )
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        #elseif os(macOS)
        _ = NSApplication.shared
        controller = NSHostingController(rootView: AnyView(rootView))
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 480),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        window.orderFrontRegardless()
        controller.view.needsLayout = true
        controller.view.layoutSubtreeIfNeeded()
        #endif
    }

    func removeContent() {
        controller.rootView = AnyView(EmptyView())
        #if os(iOS)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        window.rootViewController = nil
        window.isHidden = true
        #elseif os(macOS)
        controller.view.needsLayout = true
        controller.view.layoutSubtreeIfNeeded()
        window.contentViewController = nil
        window.orderOut(nil)
        #endif
    }
}
#endif
