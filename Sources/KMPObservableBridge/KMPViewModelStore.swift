import Combine
import SwiftUI

/// Observable storage shared by owning, observed, and environment wrappers.
///
/// The store is exposed as a projected value (`$viewModel`) so observation can
/// be propagated through SwiftUI's environment without creating subscriptions.
@dynamicMemberLookup
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

    convenience init(
        _ wrappedValue: ViewModel,
        states: [KMPState<ViewModel>],
        updatePolicy: KMPUpdatePolicy,
        failurePolicy: KMPObservationFailurePolicy,
        ownsModel: Bool,
        disposer: Disposer? = nil,
        modernObservationEnabled: Bool = true
    ) {
        self.init(
            wrappedValue,
            source: .explicit(states),
            updatePolicy: updatePolicy,
            failurePolicy: failurePolicy,
            ownsModel: ownsModel,
            disposer: disposer,
            modernObservationEnabled: modernObservationEnabled
        )
    }

    init(
        _ wrappedValue: ViewModel,
        source: KMPObservationSource<ViewModel>,
        updatePolicy: KMPUpdatePolicy,
        failurePolicy: KMPObservationFailurePolicy,
        ownsModel: Bool,
        disposer: Disposer? = nil,
        modernObservationEnabled: Bool = true
    ) {
        self.wrappedValue = wrappedValue
        self.updatePolicy = updatePolicy
        self.failurePolicy = failurePolicy
        self.modernObservationEnabled = modernObservationEnabled
        if ownsModel {
            self.disposer = disposer ?? { model in
                (model as? any KMPDisposable)?.dispose()
            }
        }
        configureModernObservation()
        startObserving(source)
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

    /// The original Kotlin object.
    ///
    /// This escape hatch is useful when a generated interop API must be used
    /// directly instead of through the bridge's projected bindings.
    public var rawModel: ViewModel {
        wrappedValue
    }

    /// Creates a native SwiftUI binding for a genuinely writable export.
    ///
    /// Read-only StateFlows don't have a `WritableKeyPath`, so the compiler
    /// correctly refuses to synthesize a binding for immutable Kotlin state.
    public subscript<Value>(
        dynamicMember keyPath: WritableKeyPath<ViewModel, Value>
    ) -> Binding<Value> {
        Binding(
            get: { [self] in
                wrappedValue[keyPath: keyPath]
            },
            set: { [self] value in
                wrappedValue[keyPath: keyPath] = value
            }
        )
    }

    /// Rebinds an externally owned model using deterministic teardown ordering.
    func rebind(to viewModel: ViewModel, states: [KMPState<ViewModel>]) {
        rebind(to: viewModel, source: .explicit(states))
    }

    /// Rebinds using exactly one observation route.
    func rebind(
        to viewModel: ViewModel,
        source: KMPObservationSource<ViewModel>
    ) {
        guard wrappedValue !== viewModel else {
            return
        }

        stopObserving()
        wrappedValue = viewModel
        startObserving(source)
        scheduleChange()
    }

    private func startObserving(
        _ source: KMPObservationSource<ViewModel>
    ) {
        generation &+= 1
        let activeGeneration = generation

        let states: [KMPState<ViewModel>]
        switch source {
        case .none:
            states = []
        case .staticPlan(let plan):
            states = [
                .custom { viewModel, notify, reportError in
                    plan.observe(
                        viewModel,
                        notify: notify,
                        reportError: reportError
                    )
                },
            ]
        case .explicit(let explicitStates):
            states = explicitStates
        }

        observations = states.map { state in
            state.observe(
                wrappedValue,
                { @MainActor [weak self] in
                    guard
                        let self,
                        self.generation == activeGeneration
                    else {
                        return
                    }
                    self.scheduleChange()
                },
                { @MainActor [weak self] error in
                    guard
                        let self,
                        self.generation == activeGeneration
                    else {
                        return
                    }
                    self.failurePolicy.report(error)
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
               let revision = modernRevision as? KMPObservationRevision {
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
            modernRevision = KMPObservationRevision()
        }
        #endif
    }

    private func trackModernAccess() {
        #if canImport(Observation)
        if modernObservationEnabled {
            if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *),
               let revision = modernRevision as? KMPObservationRevision {
                _ = revision.value
            }
        }
        #endif
    }
}

typealias KMPViewModel<ViewModel: AnyObject> = KMPViewModelStore<ViewModel>
