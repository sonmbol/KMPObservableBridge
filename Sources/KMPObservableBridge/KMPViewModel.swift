import Combine
import Foundation

#if canImport(Observation)
import Observation

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@Observable
@MainActor
private final class KMPModernRevision {
    var value: UInt = 0
}
#endif

/// Observable storage shared by owning, observed, and environment wrappers.
///
/// The store is exposed as a projected value (`$viewModel`) so observation can
/// be propagated through SwiftUI's environment without creating subscriptions.
@MainActor
public final class KMPViewModelStore<ViewModel: AnyObject>: @preconcurrency ObservableObject {
    typealias Disposer = @MainActor (ViewModel) -> Void

    public let objectWillChange = ObservableObjectPublisher()
    public private(set) var wrappedValue: ViewModel

    private var observations: [KMPObservation] = []
    private var generation: UInt = 0
    private let failurePolicy: KMPObservationFailurePolicy
    private let updatePolicy: KMPUpdatePolicy
    private var disposer: Disposer?
    private var pendingChange: Task<Void, Never>?
    private var modernRevision: AnyObject?
    private let modernObservationEnabled: Bool
    private let automaticStateFlowDiscovery: Bool

    init(
        _ wrappedValue: ViewModel,
        states: [KMPState<ViewModel>],
        updatePolicy: KMPUpdatePolicy,
        failurePolicy: KMPObservationFailurePolicy,
        ownsModel: Bool,
        disposer: Disposer? = nil,
        modernObservationEnabled: Bool = true,
        automaticStateFlowDiscovery: Bool = false
    ) {
        self.wrappedValue = wrappedValue
        self.updatePolicy = updatePolicy
        self.failurePolicy = failurePolicy
        self.modernObservationEnabled = modernObservationEnabled
        self.automaticStateFlowDiscovery = automaticStateFlowDiscovery
        if ownsModel {
            self.disposer = disposer ?? { model in
                (model as? any KMPDisposable)?.dispose()
            }
        }
        configureModernObservation()
        startObserving(states)
    }

    deinit {
        MainActor.assumeIsolated {
            pendingChange?.cancel()
            observations.forEach { $0.cancel() }
            disposer?(wrappedValue)
        }
    }

    /// Registers modern Observation access and returns the real Kotlin model.
    public var value: ViewModel {
        trackModernAccess()
        return wrappedValue
    }

    /// Rebinds an externally owned model using deterministic teardown ordering.
    func rebind(to viewModel: ViewModel, states: [KMPState<ViewModel>]) {
        guard wrappedValue !== viewModel else {
            return
        }

        stopObserving()
        wrappedValue = viewModel
        startObserving(states)
        emitChange()
    }

    private func startObserving(_ states: [KMPState<ViewModel>]) {
        generation &+= 1
        let activeGeneration = generation

        var sources = states
        #if canImport(ObjectiveC)
        if automaticStateFlowDiscovery {
            sources.append(
                .custom { viewModel, notify, reportError in
                    KMPAutomaticStateFlowRuntime.observe(
                        viewModel,
                        notify: notify,
                        reportError: reportError
                    )
                }
            )
        }
        #endif

        observations = sources.map { state in
            state.observe(
                wrappedValue,
                { [weak self] in
                    Task { @MainActor [weak self] in
                        guard
                            let self,
                            self.generation == activeGeneration
                        else {
                            return
                        }
                        self.scheduleChange()
                    }
                },
                { [weak self] error in
                    Task { @MainActor [weak self] in
                        guard
                            let self,
                            self.generation == activeGeneration
                        else {
                            return
                        }
                        self.failurePolicy.report(error)
                    }
                }
            )
        }
    }

    private func stopObserving() {
        generation &+= 1
        pendingChange?.cancel()
        pendingChange = nil
        let current = observations
        observations.removeAll(keepingCapacity: false)
        current.forEach { $0.cancel() }
    }

    private func scheduleChange() {
        switch updatePolicy {
        case .immediate:
            emitChange()
        case .coalesced:
            guard pendingChange == nil else {
                return
            }
            pendingChange = Task { @MainActor [weak self] in
                await Task.yield()
                guard let self, !Task.isCancelled else {
                    return
                }
                self.pendingChange = nil
                self.emitChange()
            }
        }
    }

    private func emitChange() {
        #if canImport(Observation)
        if modernObservationEnabled {
            if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *),
               let revision = modernRevision as? KMPModernRevision {
                revision.value &+= 1
                return
            }
        }
        #endif
        objectWillChange.send()
    }

    private func configureModernObservation() {
        #if canImport(Observation)
        guard modernObservationEnabled else {
            return
        }
        if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
            modernRevision = KMPModernRevision()
        }
        #endif
    }

    private func trackModernAccess() {
        #if canImport(Observation)
        if modernObservationEnabled {
            if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *),
               let revision = modernRevision as? KMPModernRevision {
                _ = revision.value
            }
        }
        #endif
    }
}

typealias KMPViewModel<ViewModel: AnyObject> = KMPViewModelStore<ViewModel>
