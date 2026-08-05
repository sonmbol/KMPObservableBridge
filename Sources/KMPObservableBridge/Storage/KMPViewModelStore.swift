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
    private var pendingDependencies: Set<KMPObservationDependency> = []
    private var globalRevision: AnyObject?
    private var projectedGlobalRevision: AnyObject?
    private var fieldSlots: [AnyKeyPath: KMPFieldObservationSlot] = [:]
    private let modernObservationEnabled: Bool
    private var demandObservationEnabled = false

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
        trackModernAccess(for: .global)
        return wrappedValue
    }

    /// The original Kotlin object.
    ///
    /// This escape hatch is useful when a generated interop API must be used
    /// directly instead of through the bridge's projected bindings.
    public var rawModel: ViewModel {
        wrappedValue
    }

    /// Reads the current value of a KMP state container.
    ///
    /// The projected store deliberately performs the container-to-value
    /// conversion so SwiftUI APIs receive native `String`, `Bool`, numeric, or
    /// domain values without exposing the interop container's `.value`.
    public subscript<Property>(
        dynamicMember keyPath: KeyPath<ViewModel, Property>
    ) -> Property.Value where
        Property: AsyncSequence & KMPValueProperty,
        Property.Element == Property.Value,
        Property.Element: Equatable
    {
        let value = wrappedValue[keyPath: keyPath].value
        trackModernAccess(for: .field(keyPath))
        activateDemandObservation(
            .demandEquatable(keyPath, initialValue: value),
            for: keyPath
        )
        return value
    }

    /// Lazily observes a non-equatable current-value async sequence.
    public subscript<Property>(
        dynamicMember keyPath: KeyPath<ViewModel, Property>
    ) -> Property.Value where
        Property: AsyncSequence & KMPValueProperty,
        Property.Element == Property.Value
    {
        let value = wrappedValue[keyPath: keyPath].value
        trackModernAccess(for: .field(keyPath))
        activateDemandObservation(.everyEmission(keyPath), for: keyPath)
        return value
    }

    public subscript<Property>(
        dynamicMember keyPath: KeyPath<ViewModel, Property>
    ) -> Property.Value where Property: KMPValueProperty {
        trackModernAccess(for: .field(keyPath))
        return wrappedValue[keyPath: keyPath].value
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
                trackModernAccess(for: .field(keyPath))
                return wrappedValue[keyPath: keyPath]
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
        scheduleChange(.global)
    }

    private func startObserving(
        _ source: KMPObservationSource<ViewModel>
    ) {
        generation &+= 1
        let activeGeneration = generation

        switch source {
        case .demandDriven:
            demandObservationEnabled = true
        case .staticPlan(let plan):
            demandObservationEnabled = false
            observations = [
                plan.observe(
                    wrappedValue,
                    notify: { @MainActor [weak self] dependency in
                        guard
                            let self,
                            self.generation == activeGeneration
                        else {
                            return
                        }
                        self.scheduleChange(dependency)
                    },
                    reportError: makeErrorHandler(
                        generation: activeGeneration
                    )
                ),
            ]
        case .keyed(let observe):
            demandObservationEnabled = false
            observations = [
                observe(
                    wrappedValue,
                    { @MainActor [weak self] keyPath in
                        guard
                            let self,
                            self.generation == activeGeneration
                        else {
                            return
                        }
                        self.scheduleChange(
                            keyPath.map(
                                KMPObservationDependency.field
                            ) ?? .global
                        )
                    },
                    makeErrorHandler(generation: activeGeneration)
                ),
            ]
        case .explicit(let explicitStates):
            demandObservationEnabled = false
            let reportError = makeErrorHandler(
                generation: activeGeneration
            )
            observations = explicitStates.map { state in
                state.observe(
                    wrappedValue,
                    { @MainActor [weak self] in
                        guard
                            let self,
                            self.generation == activeGeneration
                        else {
                            return
                        }
                        self.scheduleChange(state.dependency)
                    },
                    reportError
                )
            }
        }
    }

    private func makeErrorHandler(
        generation activeGeneration: UInt
    ) -> KMPObservationErrorHandler {
        { @MainActor [weak self] error in
            guard
                let self,
                self.generation == activeGeneration
            else {
                return
            }
            self.failurePolicy.report(error)
        }
    }

    private func stopObserving() {
        generation &+= 1
        pendingChange?.cancel()
        pendingChange = nil
        pendingDependencies.removeAll(keepingCapacity: true)
        demandObservationEnabled = false
        fieldSlots.values.forEach { $0.cancel() }
        let current = observations
        observations.removeAll(keepingCapacity: false)
        current.forEach { $0.cancel() }
    }

    private func activateDemandObservation<Sequence: AsyncSequence>(
        _ state: KMPState<ViewModel>,
        for keyPath: KeyPath<ViewModel, Sequence>
    ) {
        guard demandObservationEnabled else {
            return
        }
        let slot = fieldSlot(for: keyPath)
        let activeGeneration = generation
        slot.activate { [weak self] in
            guard let self else {
                return .empty
            }
            return KMPDemandObservationRegistry.shared.observe(
                wrappedValue,
                state: state,
                notify: { @MainActor [weak self] in
                    guard
                        let self,
                        self.generation == activeGeneration
                    else {
                        return
                    }
                    self.scheduleChange(.field(keyPath))
                },
                reportError: makeErrorHandler(
                    generation: activeGeneration
                )
            )
        }
    }

    private func fieldSlot(for keyPath: AnyKeyPath) -> KMPFieldObservationSlot {
        if let existing = fieldSlots[keyPath] {
            return existing
        }
        let slot = KMPFieldObservationSlot()
        fieldSlots[keyPath] = slot
        return slot
    }

    private func scheduleChange(
        _ dependency: KMPObservationDependency
    ) {
        switch updatePolicy {
        case .immediate:
            emitImmediateChange(for: dependency)
        case .coalesced:
            pendingDependencies.insert(dependency)
            guard pendingChange == nil else {
                return
            }
            pendingChange = Task { @MainActor [weak self] in
                await Task.yield()
                guard let self, !Task.isCancelled else {
                    return
                }
                self.pendingChange = nil
                let dependencies = self.pendingDependencies
                self.pendingDependencies.removeAll(keepingCapacity: true)
                self.emitCoalescedChange(for: dependencies)
            }
        }
    }

    private func emitImmediateChange(
        for dependency: KMPObservationDependency
    ) {
        #if canImport(Observation)
        if modernObservationEnabled {
            if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *),
               let revision = globalRevision as? KMPObservationRevision {
                invalidateFieldRevisions(for: dependency)
                revision.value &+= 1
                return
            }
        }
        #endif
        objectWillChange.send()
    }

    private func emitCoalescedChange(
        for dependencies: Set<KMPObservationDependency>
    ) {
        #if canImport(Observation)
        if modernObservationEnabled {
            if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *),
               let revision = globalRevision as? KMPObservationRevision {
                let isGlobal = dependencies.contains(.global)
                if isGlobal {
                    invalidateFieldRevisions(for: .global)
                } else {
                    for dependency in dependencies {
                        invalidateFieldRevisions(for: dependency)
                    }
                }
                revision.value &+= 1
                return
            }
        }
        #endif
        objectWillChange.send()
    }

    #if canImport(Observation)
    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    private func invalidateFieldRevisions(
        for dependency: KMPObservationDependency
    ) {
        switch dependency {
        case .global:
            let revision =
                projectedGlobalRevision as? KMPObservationRevision
            revision?.value &+= 1
        case .field(let keyPath):
            let revision =
                fieldSlots[keyPath]?.revision as? KMPObservationRevision
            revision?.value &+= 1
        }
    }

    #endif

    private func configureModernObservation() {
        #if canImport(Observation)
        guard modernObservationEnabled else {
            return
        }
        if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) {
            globalRevision = KMPObservationRevision()
        }
        #endif
    }

    private func trackModernAccess(
        for dependency: KMPObservationDependency
    ) {
        #if canImport(Observation)
        if modernObservationEnabled {
            if #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *),
               let globalRevision =
                   globalRevision as? KMPObservationRevision {
                switch dependency {
                case .global:
                    _ = globalRevision.value
                case .field(let keyPath):
                    let projectedGlobal: KMPObservationRevision
                    if let existing =
                        projectedGlobalRevision as? KMPObservationRevision {
                        projectedGlobal = existing
                    } else {
                        projectedGlobal = KMPObservationRevision()
                        projectedGlobalRevision = projectedGlobal
                    }
                    _ = projectedGlobal.value
                    let slot = fieldSlot(for: keyPath)
                    let revision: KMPObservationRevision
                    if let existing =
                        slot.revision as? KMPObservationRevision {
                        revision = existing
                    } else {
                        revision = KMPObservationRevision()
                        slot.revision = revision
                    }
                    _ = revision.value
                }
            }
        }
        #endif
    }
}
