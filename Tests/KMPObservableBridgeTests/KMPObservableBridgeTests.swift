import Combine
import SwiftUI
import XCTest
@testable import KMPObservableBridge

#if canImport(ObjectiveC)
private final class ObjectiveCMethodFixture: NSObject {
    @objc dynamic func objectValue() -> AnyObject? {
        nil
    }

    @objc dynamic func transformedValue(
        for input: AnyObject
    ) -> AnyObject? {
        input
    }
}
#endif

@MainActor
final class KMPObservableBridgeTests: XCTestCase {
    private final class Model {
        let subject = PassthroughSubject<Int, TestError>()
    }

    private final class StreamModel: @unchecked Sendable {
        let state = AsyncStream<Int> { _ in }
        let message = AsyncStream<String> { _ in }
        let loading = AsyncStream<Bool> { _ in }
        let progress = AsyncStream<Double> { _ in }
        let selection = AsyncStream<UUID?> { _ in }
    }

    private final class ParentModel {
        var child: StreamModel

        init(child: StreamModel) {
            self.child = child
        }
    }

    private final class ValueStream<Element: Sendable>:
        AsyncSequence,
        KMPValueProperty,
        @unchecked Sendable
    {
        private let lock = NSLock()
        private var currentValue: Element
        private let stream: AsyncStream<Element>
        private let continuation: AsyncStream<Element>.Continuation

        var value: Element {
            lock.withLock { currentValue }
        }

        init(_ value: Element) {
            currentValue = value
            var captured: AsyncStream<Element>.Continuation?
            stream = AsyncStream { captured = $0 }
            continuation = captured!
        }

        func update(_ value: Element) {
            lock.withLock {
                currentValue = value
            }
            continuation.yield(value)
        }

        func makeAsyncIterator() -> AsyncStream<Element>.Iterator {
            stream.makeAsyncIterator()
        }
    }

    private final class FlowParentModel {
        let childState: ValueStream<StreamModel?>

        init(child: StreamModel?) {
            childState = ValueStream(child)
        }
    }

    private final class DisposableModel: KMPDisposable {
        let state = AsyncStream<Int> { _ in }
        private(set) var disposalCount = 0

        func dispose() {
            disposalCount += 1
        }
    }

    private enum TestError: Error, Equatable {
        case failed
    }

    private final class NativeFlowModel: KMPNativeObservable {
        typealias Flow = KMPNativeFlow<Int, TestError, Void>

        private var onItem: ((Int, @escaping () -> Void, Void) -> Void)?
        private var onComplete: ((TestError?, Void) -> Void)?
        private(set) var cancellationCount = 0
        var isObserved: Bool {
            onItem != nil
        }

        lazy var state: Flow = { [weak self] onItem, onComplete, _ in
            self?.onItem = onItem
            self?.onComplete = onComplete
            return { [weak self] in
                self?.cancellationCount += 1
            }
        }

        var kmpObservationFlow: Flow {
            state
        }

        func emit(_ value: Int) {
            onItem?(value, {}, ())
        }

        func fail() {
            onComplete?(.failed, ())
        }
    }

    /// Represents an application-defined automatic-observation conformance.
    private final class GeneratedStyleModel: KMPAutomaticallyObservable {
        let state = PassthroughSubject<Int, Never>()

        func kmpObserveAutomatically(
            notify: @escaping KMPState<GeneratedStyleModel>.Notify,
            reportError: @escaping KMPState<GeneratedStyleModel>.ReportError
        ) -> KMPObservation {
            KMPState<GeneratedStyleModel>.publisher(\.state)
                .startObservation(
                    on: self,
                    notify: notify,
                    reportError: reportError
                )
        }
    }

    func testObservationCancellationIsIdempotent() {
        var cancellationCount = 0
        let observation = KMPObservation {
            cancellationCount += 1
        }

        observation.cancel()
        observation.cancel()

        XCTAssertEqual(cancellationCount, 1)
    }

    #if canImport(ObjectiveC)
    func testObjectiveCMethodValidationChecksArgumentCount() {
        XCTAssertNotNil(
            kmpMethod(
                ObjectiveCMethodFixture.self,
                selector: #selector(ObjectiveCMethodFixture.objectValue),
                expectedArgumentCount: 2
            )
        )
        XCTAssertNil(
            kmpMethod(
                ObjectiveCMethodFixture.self,
                selector: #selector(ObjectiveCMethodFixture.objectValue),
                expectedArgumentCount: 3
            )
        )
        XCTAssertNotNil(
            kmpMethod(
                ObjectiveCMethodFixture.self,
                selector: #selector(
                    ObjectiveCMethodFixture.transformedValue(for:)
                ),
                expectedArgumentCount: 3
            )
        )
    }
    #endif

    func testObservationCancelsWhenReleased() {
        var cancellationCount = 0

        do {
            _ = KMPObservation {
                cancellationCount += 1
            }
        }

        XCTAssertEqual(cancellationCount, 1)
    }

    func testPublisherEmissionsInvalidateAndFailureIsReported() async {
        let model = Model()
        var receivedChanges = 0
        var receivedError: TestError?
        let bridge = KMPViewModel(
            model,
            states: [.publisher(\.subject)],
            updatePolicy: .immediate,
            failurePolicy: .custom { error in
                receivedError = error as? TestError
            },
            ownsModel: false,
            modernObservationEnabled: false
        )
        let cancellable = bridge.objectWillChange.sink {
            receivedChanges += 1
        }

        model.subject.send(1)
        await settleMainActorTasks()
        XCTAssertEqual(receivedChanges, 1)

        model.subject.send(completion: .failure(.failed))
        await settleMainActorTasks()
        XCTAssertEqual(receivedError, .failed)
        withExtendedLifetime(cancellable) {}
    }

    func testNativeFlowInvalidatesReportsFailureAndCancels() async {
        let model = NativeFlowModel()
        var receivedChanges = 0
        var receivedError: TestError?
        var store: KMPViewModelStore<NativeFlowModel>? = KMPViewModelStore(
            model,
            states: [.nativeFlow(\.state)],
            updatePolicy: .immediate,
            failurePolicy: .custom { error in
                receivedError = error as? TestError
            },
            ownsModel: false,
            modernObservationEnabled: false
        )
        let cancellable = store?.objectWillChange.sink {
            receivedChanges += 1
        }

        model.emit(1)
        await settleMainActorTasks()
        XCTAssertEqual(receivedChanges, 1)

        model.fail()
        await settleMainActorTasks()
        XCTAssertEqual(receivedError, .failed)

        store = nil
        XCTAssertEqual(model.cancellationCount, 1)
        withExtendedLifetime(cancellable) {}
    }

    func testAutomaticNativeObservableWrappersUseNativeFlowNotSKIE() {
        let ownedModel = NativeFlowModel()
        let observedModel = NativeFlowModel()
        guard case .explicit(let routedStates) =
            kmpAutomaticObservationSource(
                for: ownedModel,
                strategy: .automaticSKIE
            )
        else {
            return XCTFail("Native observable was not routed explicitly")
        }
        XCTAssertEqual(routedStates.count, 1)

        let owned = KMPStateObject(wrappedValue: ownedModel)
        let observed = KMPObservedObject(observedModel)

        XCTAssertTrue(owned.wrappedValue === ownedModel)
        XCTAssertTrue(observed.wrappedValue === observedModel)
        XCTAssertTrue(ownedModel.isObserved)
        XCTAssertTrue(observedModel.isObserved)
    }

    func testExplicitAutomaticSKIEStrategy() {
        let ownedModel = Model()
        let observedModel = Model()
        let owned = KMPStateObject(
            wrappedValue: ownedModel,
            observation: .automaticSKIE
        )
        let observed = KMPObservedObject(
            observedModel,
            observation: .automaticSKIE
        )

        XCTAssertTrue(owned.wrappedValue === ownedModel)
        XCTAssertTrue(observed.wrappedValue === observedModel)
    }

    func testAutomaticSKIEIsTheDefaultObservationStrategy() {
        let ownedModel = Model()
        let observedModel = Model()
        let owned = KMPStateObject(wrappedValue: ownedModel)
        let observed = KMPObservedObject(observedModel)

        XCTAssertTrue(owned.wrappedValue === ownedModel)
        XCTAssertTrue(observed.wrappedValue === observedModel)
    }

    func testNoneAutomaticObservationExposesModelsWithoutSubscribing() {
        let ownedModel = Model()
        let observedModel = Model()
        let nativeModel = NativeFlowModel()
        let owned = KMPStateObject(
            wrappedValue: ownedModel,
            observation: .none
        )
        let observed = KMPObservedObject(
            observedModel,
            observation: .none
        )
        let disabledNative = KMPStateObject(
            wrappedValue: nativeModel,
            observation: .none
        )

        XCTAssertTrue(owned.wrappedValue === ownedModel)
        XCTAssertTrue(observed.wrappedValue === observedModel)
        XCTAssertTrue(disabledNative.wrappedValue === nativeModel)
        XCTAssertFalse(nativeModel.isObserved)
    }

    func testGeneratedAutomaticConformanceSupportsBothWrappers() {
        let ownedModel = GeneratedStyleModel()
        let observedModel = GeneratedStyleModel()
        let owned = KMPStateObject(
            wrappedValue: ownedModel,
            updatePolicy: .immediate
        )
        let observed = KMPObservedObject(
            wrappedValue: observedModel,
            updatePolicy: .immediate
        )

        XCTAssertTrue(owned.wrappedValue === ownedModel)
        XCTAssertTrue(observed.wrappedValue === observedModel)
    }

    func testRebindingCancelsOldSourceAndSuppressesStaleEmissions() async {
        let first = Model()
        let second = Model()
        var receivedChanges = 0
        let bridge = KMPViewModel(
            first,
            states: [.publisher(\.subject)],
            updatePolicy: .immediate,
            failurePolicy: .ignore,
            ownsModel: false,
            modernObservationEnabled: false
        )
        let cancellable = bridge.objectWillChange.sink {
            receivedChanges += 1
        }

        bridge.rebind(to: second, states: [.publisher(\.subject)])
        let countAfterRebind = receivedChanges
        first.subject.send(1)
        await settleMainActorTasks()
        XCTAssertEqual(receivedChanges, countAfterRebind)

        second.subject.send(2)
        await settleMainActorTasks()
        XCTAssertEqual(receivedChanges, countAfterRebind + 1)
        XCTAssertTrue(bridge.wrappedValue === second)
        withExtendedLifetime(cancellable) {}
    }

    func testOwnedModelDisposesExactlyOnceAfterBridgeRelease() {
        let model = Model()
        weak var weakModel = model
        var disposalCount = 0
        var bridge: KMPViewModel<Model>? = KMPViewModel(
            model,
            states: [],
            updatePolicy: .immediate,
            failurePolicy: .ignore,
            ownsModel: true,
            disposer: { disposedModel in
                XCTAssertTrue(disposedModel === model)
                disposalCount += 1
            },
            modernObservationEnabled: false
        )

        bridge = nil

        XCTAssertNil(bridge)
        XCTAssertEqual(disposalCount, 1)
        XCTAssertNotNil(weakModel)
    }

    func testBridgeAndModelDeallocateWithoutRetainCycle() {
        weak var weakModel: Model?
        weak var weakBridge: KMPViewModel<Model>?

        do {
            let model = Model()
            let bridge = KMPViewModel(
                model,
                states: [.publisher(\.subject)],
                updatePolicy: .immediate,
                failurePolicy: .ignore,
                ownsModel: false,
                modernObservationEnabled: false
            )
            weakModel = model
            weakBridge = bridge
        }

        XCTAssertNil(weakBridge)
        XCTAssertNil(weakModel)
    }

    func testAsyncSequenceNormalCompletionDoesNotReportError() async {
        let model = Model()
        var errors: [Error] = []
        let sequence = AsyncStream<Int> { continuation in
            continuation.yield(1)
            continuation.finish()
        }
        let bridge = KMPViewModel(
            model,
            states: [.asyncSequence { _ in sequence }],
            updatePolicy: .immediate,
            failurePolicy: .custom { errors.append($0) },
            ownsModel: false,
            modernObservationEnabled: false
        )

        await settleMainActorTasks()

        XCTAssertTrue(errors.isEmpty)
        withExtendedLifetime(bridge) {}
    }

    func testAsyncSequenceFailureIsReported() async {
        let model = Model()
        let failureReported = expectation(description: "failure reported")
        var receivedError: TestError?
        let sequence = AsyncThrowingStream<Int, Error> { continuation in
            continuation.finish(throwing: TestError.failed)
        }
        let bridge = KMPViewModel(
            model,
            states: [.asyncSequence { _ in sequence }],
            updatePolicy: .immediate,
            failurePolicy: .custom {
                receivedError = $0 as? TestError
                failureReported.fulfill()
            },
            ownsModel: false,
            modernObservationEnabled: false
        )

        await fulfillment(of: [failureReported], timeout: 1)

        XCTAssertEqual(receivedError, .failed)
        withExtendedLifetime(bridge) {}
    }

    func testAsyncSequenceIsCancelledWithBridge() async {
        let model = Model()
        let termination = expectation(description: "sequence terminated")
        let sequence = AsyncStream<Int> { continuation in
            continuation.onTermination = { reason in
                if case .cancelled = reason {
                    termination.fulfill()
                }
            }
        }
        var bridge: KMPViewModel<Model>? = KMPViewModel(
            model,
            states: [.asyncSequence { _ in sequence }],
            updatePolicy: .immediate,
            failurePolicy: .ignore,
            ownsModel: false,
            modernObservationEnabled: false
        )
        await settleMainActorTasks()

        bridge = nil

        await fulfillment(of: [termination], timeout: 1)
        XCTAssertNil(bridge)
    }

    func testBackgroundCallbackInvalidatesOnMainActor() async {
        let model = Model()
        let change = expectation(description: "main actor invalidation")
        let state = KMPState<Model>.callback { _, notify, _ in
            DispatchQueue.global().async {
                notify()
            }
            return .empty
        }
        let bridge = KMPViewModel(
            model,
            states: [state],
            updatePolicy: .immediate,
            failurePolicy: .ignore,
            ownsModel: false,
            modernObservationEnabled: false
        )
        let cancellable = bridge.objectWillChange.sink {
            XCTAssertTrue(Thread.isMainThread)
            change.fulfill()
        }

        await fulfillment(of: [change], timeout: 1)
        withExtendedLifetime(cancellable) {}
    }

    func testHighFrequencyPublisherDoesNotDropInvalidations() async {
        let model = Model()
        var receivedChanges = 0
        let bridge = KMPViewModel(
            model,
            states: [.publisher(\.subject)],
            updatePolicy: .immediate,
            failurePolicy: .ignore,
            ownsModel: false,
            modernObservationEnabled: false
        )
        let cancellable = bridge.objectWillChange.sink {
            receivedChanges += 1
        }

        for value in 0..<1_000 {
            model.subject.send(value)
        }
        await settleMainActorTasks()

        XCTAssertEqual(receivedChanges, 1_000)
        withExtendedLifetime(cancellable) {}
    }

    func testSingleStateConvenienceWrappersExposeOriginalModel() {
        let ownedModel = StreamModel()
        let observedModel = StreamModel()
        let owned = KMPStateObject(
            wrappedValue: ownedModel,
            state: \.state
        )
        let observed = KMPObservedObject(
            observedModel,
            state: \.state
        )

        XCTAssertTrue(owned.wrappedValue === ownedModel)
        XCTAssertTrue(observed.wrappedValue === observedModel)
    }

    func testTextAcceptsStringValuePropertyWithoutExplicitValueRead() {
        let message = ValueStream("Ready")
        _ = Text(message)
    }

    func testHeterogeneousStateKeyPathConvenience() {
        let ownedModel = StreamModel()
        let observedModel = StreamModel()
        let owned = KMPStateObject(
            wrappedValue: ownedModel,
            states:
                \.state,
                \.message,
                \.loading,
                \.progress,
                \.selection
        )
        let observed = KMPObservedObject(
            observedModel,
            states: \.state, \.message
        )

        XCTAssertTrue(owned.wrappedValue === ownedModel)
        XCTAssertTrue(observed.wrappedValue === observedModel)
    }

    func testCoalescedPolicyBatchesSynchronousEmissions() async {
        let model = Model()
        var receivedChanges = 0
        let store = KMPViewModelStore(
            model,
            states: [.publisher(\.subject)],
            updatePolicy: .coalesced,
            failurePolicy: .ignore,
            ownsModel: false,
            modernObservationEnabled: false
        )
        let cancellable = store.objectWillChange.sink {
            receivedChanges += 1
        }

        for value in 0..<100 {
            model.subject.send(value)
        }
        await settleMainActorTasks()

        XCTAssertEqual(receivedChanges, 1)
        withExtendedLifetime(cancellable) {}
    }

    func testDisposableProtocolIsUsedForOwnedModel() {
        let model = DisposableModel()
        var store: KMPViewModelStore<DisposableModel>? = KMPViewModelStore(
            model,
            states: [],
            updatePolicy: .coalesced,
            failurePolicy: .ignore,
            ownsModel: true,
            modernObservationEnabled: false
        )

        store = nil

        XCTAssertNil(store)
        XCTAssertEqual(model.disposalCount, 1)
    }

    func testCancellationIsReentrantSafe() {
        weak var weakObservation: KMPObservation?
        var cancellationCount = 0
        let observation = KMPObservation {
            cancellationCount += 1
            weakObservation?.cancel()
        }
        weakObservation = observation

        observation.cancel()

        XCTAssertEqual(cancellationCount, 1)
    }

    func testDirectChildRebindsWithoutDisposal() {
        let first = StreamModel()
        let second = StreamModel()
        let parent = ParentModel(child: first)
        var wrapper = KMPChildObject(
            parent: parent,
            child: \.child,
            state: \.state,
            failurePolicy: .ignore
        )

        XCTAssertTrue(wrapper.wrappedValue === first)
        parent.child = second
        wrapper.update()

        XCTAssertTrue(wrapper.wrappedValue === second)
    }

    func testOptionalFlowChildRebindsAndReleasesPreviousChild() async {
        var first: StreamModel? = StreamModel()
        weak var weakFirst = first
        let second = StreamModel()
        let parent = FlowParentModel(child: first)
        let wrapper = KMPOptionalChildObject(
            parent: parent,
            child: \.childState,
            state: \.state,
            failurePolicy: .ignore
        )

        XCTAssertTrue(wrapper.wrappedValue === first)
        first = nil
        parent.childState.update(second)
        await settleMainActorTasks()

        XCTAssertTrue(wrapper.wrappedValue === second)
        XCTAssertNil(weakFirst)
    }

    func testOptionalFlowChildSupportsNil() async {
        let child = StreamModel()
        let parent = FlowParentModel(child: child)
        let wrapper = KMPOptionalChildObject(
            parent: parent,
            child: \.childState,
            state: \.state,
            failurePolicy: .ignore
        )

        parent.childState.update(nil)
        await settleMainActorTasks()

        XCTAssertNil(wrapper.wrappedValue)
        XCTAssertNil(wrapper.projectedValue)
    }

    func testProjectedStoreCanBeInjectedWithoutCreatingAnotherStore() {
        let model = StreamModel()
        let owner = KMPStateObject(
            wrappedValue: model,
            state: \.state,
            failurePolicy: .ignore
        )

        _ = EmptyView().kmpEnvironmentObject(owner.projectedValue)

        XCTAssertTrue(owner.projectedValue.value === model)
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    func testModernObservationPathTracksStoreValue() async {
        let model = Model()
        let changed = expectation(description: "Observation invalidated")
        let store = KMPViewModelStore(
            model,
            states: [.publisher(\.subject)],
            updatePolicy: .immediate,
            failurePolicy: .ignore,
            ownsModel: false
        )

        withObservationTracking {
            _ = store.value
        } onChange: {
            changed.fulfill()
        }

        model.subject.send(1)

        await fulfillment(of: [changed], timeout: 1)
    }

    private func settleMainActorTasks() async {
        for _ in 0..<4 {
            await Task.yield()
        }
    }
}
