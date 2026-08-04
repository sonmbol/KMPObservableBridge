#if os(iOS) || os(macOS)
import Foundation
@testable import KMPObservableBridge

enum HostedField: Hashable {
    case first
    case second
}

enum HostingObservationMode {
    case runtime
    case forcedFallback
}

@MainActor
struct HostingContext {
    let model: HostingModel
    let probe: HostingRenderProbe
    let harness: AppleHostingHarness
}

@MainActor
final class HostingRenderProbe {
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

final class HostingSignal:
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
        let action = onStop
        onStop = nil
        action?()
    }
}

@MainActor
final class HostingModel: KMPStaticallyObservable {
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
#endif
