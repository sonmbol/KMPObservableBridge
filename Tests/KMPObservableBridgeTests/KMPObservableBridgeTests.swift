import Combine
import SwiftUI
import XCTest
@testable import KMPObservableBridge

@MainActor
final class KMPObservableBridgeTests: XCTestCase {
    private final class Model: KMPStaticallyObservable {
        let subject = PassthroughSubject<Int, TestError>()
        var title = "Initial"

        static var kmpObservationPlan: KMPObservationPlan<Model> {
            KMPObservationPlan(.publisher(\.subject))
        }

        static func kmpStartObservation(
            on model: Model,
            notify: @escaping KMPObservationNotify,
            reportError: @escaping KMPObservationErrorHandler
        ) -> KMPObservation {
            kmpObservationPlan.startObservation(
                on: model, notify: notify, reportError: reportError
            )
        }
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
        private(set) var iteratorCount = 0

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
            iteratorCount += 1
            return stream.makeAsyncIterator()
        }
    }

    private final class FlowParentModel {
        let childState: ValueStream<StreamModel?>

        init(child: StreamModel?) {
            childState = ValueStream(child)
        }
    }

    private final class FieldModel: KMPStaticallyObservable {
        let first = ValueStream(0)
        let second = ValueStream(0)

        static var kmpObservationPlan: KMPObservationPlan<FieldModel> {
            KMPObservationPlan(
                .equatable(\.first),
                .equatable(\.second)
            )
        }

        static func kmpStartObservation(
            on model: FieldModel,
            notify: @escaping KMPObservationNotify,
            reportError: @escaping KMPObservationErrorHandler
        ) -> KMPObservation {
            kmpObservationPlan.startObservation(
                on: model,
                notify: notify,
                reportError: reportError
            )
        }
    }

    private final class DemandModel: KMPStaticallyObservable {
        let first = ValueStream(0)
        let second = ValueStream(0)

        static var kmpObservationStrategy: KMPObservationStrategy {
            .demandDriven
        }

        static func kmpStartObservation(
            on model: DemandModel,
            notify: @escaping KMPObservationNotify,
            reportError: @escaping KMPObservationErrorHandler
        ) -> KMPObservation {
            .empty
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

    private final class LockedCounter: @unchecked Sendable {
        private let lock = NSLock()
        private var storage = 0

        var value: Int {
            lock.withLock { storage }
        }

        func increment() {
            lock.withLock {
                storage += 1
            }
        }
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

        static var kmpObservationPlan: KMPObservationPlan<NativeFlowModel> {
            KMPObservationPlan(.nativeFlow(\.kmpObservationFlow))
        }

        func emit(_ value: Int) {
            onItem?(value, {}, ())
        }

        func fail() {
            onComplete?(.failed, ())
        }
    }

    /// Represents a macro-expanded static-observation conformance.
    private final class MacroStyleModel: KMPStaticallyObservable {
        let state = PassthroughSubject<Int, Never>()

        static var kmpObservationPlan: KMPObservationPlan<MacroStyleModel> {
            KMPObservationPlan(.publisher(\.state))
        }

        static func kmpStartObservation(
            on model: MacroStyleModel,
            notify: @escaping KMPObservationNotify,
            reportError: @escaping KMPObservationErrorHandler
        ) -> KMPObservation {
            kmpObservationPlan.startObservation(
                on: model, notify: notify, reportError: reportError
            )
        }
    }

    private final class CountingSequence: AsyncSequence, @unchecked Sendable {
        typealias Element = Int
        private let stream: AsyncStream<Int>
        private let continuation: AsyncStream<Int>.Continuation
        private(set) var iteratorCount = 0
        private(set) var cancellationCount = 0

        init() {
            var captured: AsyncStream<Int>.Continuation?
            stream = AsyncStream { captured = $0 }
            continuation = captured!
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.cancellationCount += 1 }
            }
        }

        func makeAsyncIterator() -> AsyncStream<Int>.Iterator {
            iteratorCount += 1
            return stream.makeAsyncIterator()
        }

        func emit(_ value: Int) {
            continuation.yield(value)
        }
    }

    private final class SharedModel: KMPStaticallyObservable {
        let state = CountingSequence()

        static var kmpObservationPlan: KMPObservationPlan<SharedModel> {
            KMPObservationPlan(.equatable(\.state))
        }

        static func kmpStartObservation(
            on model: SharedModel,
            notify: @escaping KMPObservationNotify,
            reportError: @escaping KMPObservationErrorHandler
        ) -> KMPObservation {
            kmpObservationPlan.startObservation(
                on: model, notify: notify, reportError: reportError
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
        let bridge = KMPViewModelStore(
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

    func testNativeObservableStaticPlanSupportsBothWrappers() {
        let ownedModel = NativeFlowModel()
        let observedModel = NativeFlowModel()

        let owned = KMPStateObject(wrappedValue: ownedModel)
        let observed = KMPObservedObject(observedModel)

        XCTAssertTrue(owned.wrappedValue === ownedModel)
        XCTAssertTrue(observed.wrappedValue === observedModel)
        XCTAssertTrue(ownedModel.isObserved)
        XCTAssertTrue(observedModel.isObserved)
    }

    func testStaticPlanIsTheDefaultObservationStrategy() {
        let ownedModel = Model()
        let observedModel = Model()
        let owned = KMPStateObject(wrappedValue: ownedModel)
        let observed = KMPObservedObject(observedModel)

        XCTAssertTrue(owned.wrappedValue === ownedModel)
        XCTAssertTrue(observed.wrappedValue === observedModel)
    }

    func testStaticStateObjectDefersModelConstructionToSwiftUIStorage() {
        var constructionCount = 0

        func makeModel() -> Model {
            constructionCount += 1
            return Model()
        }

        _ = KMPStateObject(wrappedValue: makeModel())

        XCTAssertEqual(constructionCount, 0)
    }

    func testInjectedStaticStateObjectDefersInjectorConstruction() {
        @MainActor
        final class Injector {
            let model = Model()
        }
        var constructionCount = 0

        func makeInjector() -> Injector {
            constructionCount += 1
            return Injector()
        }

        _ = KMPStateObject(
            injector: makeInjector(),
            viewModel: \.model
        )

        XCTAssertEqual(constructionCount, 0)
    }

    func testProjectedStoreCreatesBindingForWritableExport() {
        let model = Model()
        let owner = KMPStateObject(wrappedValue: model)
        let binding: Binding<String> = owner.projectedValue.title

        XCTAssertEqual(binding.wrappedValue, "Initial")
        binding.wrappedValue = "Updated"
        XCTAssertEqual(model.title, "Updated")
        XCTAssertTrue(owner.projectedValue.rawModel === model)
    }

    func testMacroStyleConformanceSupportsBothWrappers() {
        let ownedModel = MacroStyleModel()
        let observedModel = MacroStyleModel()
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

    func testDemandDrivenStoreStartsOnlyAccessedField() async {
        let model = DemandModel()
        let store = KMPViewModelStore(
            model,
            source: .demandDriven,
            updatePolicy: .immediate,
            failurePolicy: .ignore,
            ownsModel: false,
            modernObservationEnabled: false
        )
        var changes = 0
        let cancellable = store.objectWillChange.sink { changes += 1 }

        XCTAssertEqual(model.first.iteratorCount, 0)
        XCTAssertEqual(model.second.iteratorCount, 0)

        _ = store.first
        await settleMainActorTasks()
        XCTAssertEqual(model.first.iteratorCount, 1)
        XCTAssertEqual(model.second.iteratorCount, 0)

        model.first.update(1)
        for _ in 0..<20 where changes == 0 {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTAssertEqual(changes, 1)
        withExtendedLifetime(cancellable) {}
    }

    func testDemandDrivenStoresShareAccessedFieldCollector() async {
        let model = DemandModel()
        let first = KMPViewModelStore(
            model,
            source: .demandDriven,
            updatePolicy: .immediate,
            failurePolicy: .ignore,
            ownsModel: false,
            modernObservationEnabled: false
        )
        let second = KMPViewModelStore(
            model,
            source: .demandDriven,
            updatePolicy: .immediate,
            failurePolicy: .ignore,
            ownsModel: false,
            modernObservationEnabled: false
        )

        _ = first.first
        _ = second.first
        await settleMainActorTasks()

        XCTAssertEqual(model.first.iteratorCount, 1)
        XCTAssertEqual(model.second.iteratorCount, 0)
        withExtendedLifetime((first, second)) {}
    }

    func testStaticHubSharesCollectionAndSuppressesDuplicates() async {
        let model = SharedModel()
        var firstChanges = 0
        var secondChanges = 0
        var first: KMPViewModelStore<SharedModel>? = KMPViewModelStore(
            model,
            source: .staticPlan(SharedModel.kmpObservationPlan),
            updatePolicy: .immediate,
            failurePolicy: .ignore,
            ownsModel: false,
            modernObservationEnabled: false
        )
        var second: KMPViewModelStore<SharedModel>? = KMPViewModelStore(
            model,
            source: .staticPlan(SharedModel.kmpObservationPlan),
            updatePolicy: .immediate,
            failurePolicy: .ignore,
            ownsModel: false,
            modernObservationEnabled: false
        )
        let firstCancellable = first?.objectWillChange.sink { firstChanges += 1 }
        let secondCancellable = second?.objectWillChange.sink { secondChanges += 1 }

        await settleMainActorTasks()
        XCTAssertEqual(model.state.iteratorCount, 1)
        model.state.emit(1)
        model.state.emit(1)
        model.state.emit(2)
        for _ in 0..<20 where firstChanges < 2 || secondChanges < 2 {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTAssertEqual(firstChanges, 2)
        XCTAssertEqual(secondChanges, 2)

        first = nil
        XCTAssertEqual(model.state.cancellationCount, 0)
        second = nil
        await settleMainActorTasks()
        XCTAssertEqual(model.state.cancellationCount, 1)
        withExtendedLifetime((firstCancellable, secondCancellable)) {}
    }

    func testStaticHubSupportsReentrantListenerCancellation() async {
        let model = Model()
        let plan = KMPObservationPlan<Model>(.publisher(\.subject))
        var firstChanges = 0
        var secondChanges = 0
        var second: KMPObservation?
        let first = plan.startObservation(
            on: model,
            notify: {
                firstChanges += 1
                second?.cancel()
            },
            reportError: { _ in }
        )
        second = plan.startObservation(
            on: model,
            notify: { secondChanges += 1 },
            reportError: { _ in }
        )

        model.subject.send(1)
        await settleMainActorTasks()
        model.subject.send(2)
        await settleMainActorTasks()

        XCTAssertEqual(firstChanges, 2)
        XCTAssertLessThanOrEqual(secondChanges, 1)
        withExtendedLifetime((first, second)) {}
    }

    func testRebindingCancelsOldSourceAndSuppressesStaleEmissions() async {
        let first = Model()
        let second = Model()
        var receivedChanges = 0
        let bridge = KMPViewModelStore(
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

    func testRebindingUsesCoalescedUpdatePolicy() async {
        let first = Model()
        let second = Model()
        var receivedChanges = 0
        let bridge = KMPViewModelStore(
            first,
            states: [.publisher(\.subject)],
            updatePolicy: .coalesced,
            failurePolicy: .ignore,
            ownsModel: false,
            modernObservationEnabled: false
        )
        let cancellable = bridge.objectWillChange.sink {
            receivedChanges += 1
        }

        bridge.rebind(to: second, states: [.publisher(\.subject)])
        second.subject.send(1)
        second.subject.send(2)
        await settleMainActorTasks()

        XCTAssertEqual(receivedChanges, 1)
        withExtendedLifetime(cancellable) {}
    }

    func testOwnedModelDisposesExactlyOnceAfterBridgeRelease() {
        let model = Model()
        let weakModel = WeakReference(model)
        var disposalCount = 0
        var bridge: KMPViewModelStore<Model>? = KMPViewModelStore(
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
        XCTAssertNotNil(weakModel.value)
    }

    func testBridgeAndModelDeallocateWithoutRetainCycle() {
        weak var weakModel: Model?
        weak var weakBridge: KMPViewModelStore<Model>?

        do {
            let model = Model()
            let bridge = KMPViewModelStore(
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
        let bridge = KMPViewModelStore(
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
        let bridge = KMPViewModelStore(
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
        var bridge: KMPViewModelStore<Model>? = KMPViewModelStore(
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
                Task { @MainActor in
                    notify()
                }
            }
            return .empty
        }
        let bridge = KMPViewModelStore(
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
        let bridge = KMPViewModelStore(
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

    func testProjectedStoreReturnsNativeContainerValue() {
        let child = StreamModel()
        let model = FlowParentModel(child: child)
        let store = KMPViewModelStore(
            model,
            states: [],
            updatePolicy: .coalesced,
            failurePolicy: .ignore,
            ownsModel: false,
            modernObservationEnabled: false
        )

        let projectedChild: StreamModel? = store.childState

        XCTAssertTrue(projectedChild === child)
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
        let weakFirst = WeakReference(first)
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
        XCTAssertNil(weakFirst.value)
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

    func testOptionalFlowChildRebindsWhenParentIdentityChanges() async {
        let firstChild = StreamModel()
        let secondChild = StreamModel()
        var firstParent: FlowParentModel? = FlowParentModel(child: firstChild)
        let secondParent = FlowParentModel(child: secondChild)
        let weakFirstParent = WeakReference(firstParent)
        let store = KMPOptionalChildStore(
            parent: firstParent!,
            parentState: .asyncSequence(\.childState),
            currentChild: { $0.childState.value },
            childStates: [.asyncSequence(\.state)],
            updatePolicy: .coalesced,
            failurePolicy: .ignore
        )

        XCTAssertTrue(store.child === firstChild)

        store.rebind(
            to: secondParent,
            parentState: .asyncSequence(\.childState),
            currentChild: { $0.childState.value }
        )
        firstParent = nil
        await settleMainActorTasks()

        XCTAssertTrue(store.child === secondChild)
        XCTAssertNil(weakFirstParent.value)
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

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    func testModernObservationTracksProjectedFieldsIndependently() async {
        let model = FieldModel()
        let changed = expectation(description: "First field invalidated")
        let invalidationCount = LockedCounter()
        let store = KMPViewModelStore(
            model,
            source: .staticPlan(FieldModel.kmpObservationPlan),
            updatePolicy: .immediate,
            failurePolicy: .ignore,
            ownsModel: false
        )

        withObservationTracking {
            _ = store.first
        } onChange: {
            invalidationCount.increment()
            changed.fulfill()
        }

        model.second.update(1)
        await settleMainActorTasks()
        XCTAssertEqual(invalidationCount.value, 0)

        model.first.update(1)
        await fulfillment(of: [changed], timeout: 1)
        XCTAssertEqual(invalidationCount.value, 1)
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    func testGlobalObservationInvalidatesForEveryField() async {
        let model = FieldModel()
        let changed = expectation(description: "Global dependency invalidated")
        let store = KMPViewModelStore(
            model,
            source: .staticPlan(FieldModel.kmpObservationPlan),
            updatePolicy: .immediate,
            failurePolicy: .ignore,
            ownsModel: false
        )

        withObservationTracking {
            _ = store.value
        } onChange: {
            changed.fulfill()
        }

        model.second.update(1)
        await fulfillment(of: [changed], timeout: 1)
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    func testCoalescingPreservesIndependentFieldChanges() async {
        let model = FieldModel()
        let firstChanged = expectation(description: "First invalidated")
        let secondChanged = expectation(description: "Second invalidated")
        let store = KMPViewModelStore(
            model,
            source: .staticPlan(FieldModel.kmpObservationPlan),
            updatePolicy: .coalesced,
            failurePolicy: .ignore,
            ownsModel: false
        )

        withObservationTracking {
            _ = store.first
        } onChange: {
            firstChanged.fulfill()
        }
        withObservationTracking {
            _ = store.second
        } onChange: {
            secondChanged.fulfill()
        }

        model.first.update(1)
        model.second.update(1)

        await fulfillment(
            of: [firstChanged, secondChanged],
            timeout: 1
        )
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    func testCustomGlobalAdapterInvalidatesProjectedFields() async {
        let model = FieldModel()
        var notify: KMPObservationNotify?
        let changed = expectation(description: "Projected field invalidated")
        let store = KMPViewModelStore(
            model,
            states: [
                .custom { _, callback, _ in
                    notify = callback
                    return .empty
                },
            ],
            updatePolicy: .immediate,
            failurePolicy: .ignore,
            ownsModel: false
        )

        withObservationTracking {
            _ = store.first
        } onChange: {
            changed.fulfill()
        }

        notify?()
        await fulfillment(of: [changed], timeout: 1)
    }

    private func settleMainActorTasks() async {
        for _ in 0..<4 {
            await Task.yield()
        }
    }
}
