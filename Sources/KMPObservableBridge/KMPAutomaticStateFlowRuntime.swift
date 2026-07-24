#if canImport(ObjectiveC)
import Foundation
import ObjectiveC.runtime

/// Runtime support for lazily observing SKIE-exported StateFlows.
///
/// Kotlin/Native does not publish Objective-C property metadata for Kotlin
/// properties. It does, however, publish their getters as Objective-C methods.
/// This runtime wraps eligible getters once per class and inspects only values
/// returned by getters the application naturally calls. It never invokes an
/// unknown Kotlin method speculatively.
@MainActor
enum KMPAutomaticStateFlowRuntime {
    static func observe(
        _ model: AnyObject,
        notify: @escaping @Sendable () -> Void,
        reportError: @escaping @Sendable (Error) -> Void
    ) -> KMPObservation {
        guard let hub = KMPStateFlowRuntimeRegistry.shared.hub(for: model) else {
            return .empty
        }

        let listener = hub.addListener(
            notify: notify,
            reportError: reportError
        )
        return KMPObservation {
            hub.removeListener(listener)
        }
    }
}

private final class KMPStateFlowRuntimeRegistry: @unchecked Sendable {
    static let shared = KMPStateFlowRuntimeRegistry()

    private struct MethodKey: Hashable {
        let type: ObjectIdentifier
        let selector: Selector
    }

    private let lock = NSRecursiveLock()
    private var installedMethods: Set<MethodKey> = []
    private var replacementImplementations: [MethodKey: IMP] = [:]
    private var associationKey: UInt8 = 0

    private init() {}

    func hub(for model: AnyObject) -> KMPStateFlowObservationHub? {
        lock.withLock {
            if let existing = objc_getAssociatedObject(
                model,
                &associationKey
            ) as? KMPStateFlowObservationHub {
                return existing
            }

            guard
                let modelClass: AnyClass = object_getClass(model),
                let descriptor = runtimeDescriptor(for: modelClass)
            else {
                return nil
            }

            installInterceptors(on: modelClass, descriptor: descriptor)
            let hub = KMPStateFlowObservationHub(descriptor: descriptor)
            objc_setAssociatedObject(
                model,
                &associationKey,
                hub,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            return hub
        }
    }

    private func runtimeDescriptor(
        for modelClass: AnyClass
    ) -> KMPStateFlowRuntimeDescriptor? {
        guard let modelImage = class_getImageName(modelClass) else {
            return nil
        }

        var protocolCount: UInt32 = 0
        guard let protocols = objc_copyProtocolList(&protocolCount) else {
            return nil
        }
        defer { free(UnsafeMutableRawPointer(protocols)) }

        for index in 0..<Int(protocolCount) {
            let candidate = protocols[index]
            let name = String(cString: protocol_getName(candidate))
            let suffix = "Kotlinx_coroutines_coreStateFlow"
            guard name.hasSuffix(suffix) else {
                continue
            }

            let modulePrefix = String(name.dropLast(suffix.count))
            guard let iteratorClass = NSClassFromString(
                "\(modulePrefix)SkieColdFlowIterator"
            ),
            let iteratorImage = class_getImageName(iteratorClass),
            strcmp(modelImage, iteratorImage) == 0 else {
                continue
            }

            return KMPStateFlowRuntimeDescriptor(
                stateFlowProtocol: candidate,
                iteratorClass: iteratorClass
            )
        }
        return nil
    }

    private func installInterceptors(
        on modelClass: AnyClass,
        descriptor: KMPStateFlowRuntimeDescriptor
    ) {
        var methodCount: UInt32 = 0
        guard let methods = class_copyMethodList(modelClass, &methodCount) else {
            return
        }
        defer { free(methods) }

        for index in 0..<Int(methodCount) {
            let method = methods[index]
            guard isObjectReturningZeroArgumentMethod(method) else {
                continue
            }

            let selector = method_getName(method)
            let key = MethodKey(
                type: ObjectIdentifier(modelClass),
                selector: selector
            )
            guard installedMethods.insert(key).inserted else {
                continue
            }

            typealias Getter = @convention(c) (
                AnyObject,
                Selector
            ) -> AnyObject?
            let original = unsafeBitCast(
                method_getImplementation(method),
                to: Getter.self
            )
            let replacement: @convention(block) (AnyObject) -> AnyObject? = {
                [weak self] object in
                let value = original(object, selector)
                if let value,
                   class_conformsToProtocol(
                       object_getClass(value),
                       descriptor.stateFlowProtocol
                   ),
                   let hub = self?.existingHub(for: object) {
                    hub.discover(
                        flow: value,
                        selector: selector
                    )
                }
                return value
            }

            let implementation = imp_implementationWithBlock(replacement)
            replacementImplementations[key] = implementation
            method_setImplementation(method, implementation)
        }
    }

    private func existingHub(
        for model: AnyObject
    ) -> KMPStateFlowObservationHub? {
        lock.withLock {
            objc_getAssociatedObject(
                model,
                &associationKey
            ) as? KMPStateFlowObservationHub
        }
    }

    private func isObjectReturningZeroArgumentMethod(_ method: Method) -> Bool {
        guard method_getNumberOfArguments(method) == 2 else {
            return false
        }
        let returnType = method_copyReturnType(method)
        defer { free(returnType) }
        return String(cString: returnType).first == "@"
    }
}

private struct KMPStateFlowRuntimeDescriptor: @unchecked Sendable {
    let stateFlowProtocol: Protocol
    let iteratorClass: AnyClass
}

private final class KMPStateFlowObservationHub: @unchecked Sendable {
    typealias ListenerID = UUID

    private struct Listener {
        let notify: @Sendable () -> Void
        let reportError: @Sendable (Error) -> Void
    }

    private struct ActiveFlow {
        let identity: ObjectIdentifier
        let observation: KMPDynamicSKIEObservation
    }

    private let descriptor: KMPStateFlowRuntimeDescriptor
    private let lock = NSRecursiveLock()
    private var listeners: [ListenerID: Listener] = [:]
    private var activeFlows: [Selector: ActiveFlow] = [:]

    init(descriptor: KMPStateFlowRuntimeDescriptor) {
        self.descriptor = descriptor
    }

    deinit {
        let observations = lock.withLock {
            let current = activeFlows.values.map(\.observation)
            activeFlows.removeAll()
            listeners.removeAll()
            return current
        }
        observations.forEach { $0.cancel() }
    }

    func addListener(
        notify: @escaping @Sendable () -> Void,
        reportError: @escaping @Sendable (Error) -> Void
    ) -> ListenerID {
        lock.withLock {
            let id = ListenerID()
            listeners[id] = Listener(
                notify: notify,
                reportError: reportError
            )
            return id
        }
    }

    func removeListener(_ id: ListenerID) {
        let observations: [KMPDynamicSKIEObservation] = lock.withLock {
            listeners.removeValue(forKey: id)
            guard listeners.isEmpty else {
                return []
            }
            let current = activeFlows.values.map(\.observation)
            activeFlows.removeAll()
            return current
        }
        observations.forEach { $0.cancel() }
    }

    func discover(flow: AnyObject, selector: Selector) {
        let identity = ObjectIdentifier(flow)
        let oldObservation: KMPDynamicSKIEObservation? = lock.withLock {
            if activeFlows[selector]?.identity == identity {
                return nil
            }

            let old = activeFlows.removeValue(forKey: selector)?.observation
            guard !listeners.isEmpty,
                  let observation = KMPDynamicSKIEObservation(
                      flow: flow,
                      iteratorClass: descriptor.iteratorClass,
                      onValue: { [weak self] in
                          self?.notifyListeners()
                      },
                      onError: { [weak self] error in
                          self?.report(error)
                      }
                  ) else {
                return old
            }
            activeFlows[selector] = ActiveFlow(
                identity: identity,
                observation: observation
            )
            observation.start()
            return old
        }
        oldObservation?.cancel()
    }

    private func notifyListeners() {
        let callbacks = lock.withLock {
            listeners.values.map(\.notify)
        }
        callbacks.forEach { $0() }
    }

    private func report(_ error: Error) {
        let callbacks = lock.withLock {
            listeners.values.map(\.reportError)
        }
        callbacks.forEach { $0(error) }
    }
}

private final class KMPDynamicSKIEObservation: @unchecked Sendable {
    private typealias Alloc = @convention(c) (
        AnyClass,
        Selector
    ) -> AnyObject
    private typealias Initialize = @convention(c) (
        AnyObject,
        Selector,
        AnyObject
    ) -> AnyObject
    private typealias HasNext = @convention(c) (
        AnyObject,
        Selector,
        @convention(block) (NSNumber?, NSError?) -> Void
    ) -> Void
    private typealias Next = @convention(c) (
        AnyObject,
        Selector
    ) -> AnyObject?
    private typealias Cancel = @convention(c) (
        AnyObject,
        Selector
    ) -> Void

    private let lock = NSRecursiveLock()
    private let iterator: AnyObject
    private let hasNext: HasNext
    private let next: Next
    private let cancelIterator: Cancel
    private let onValue: @Sendable () -> Void
    private let onError: @Sendable (Error) -> Void
    private var isCancelled = false

    init?(
        flow: AnyObject,
        iteratorClass: AnyClass,
        onValue: @escaping @Sendable () -> Void,
        onError: @escaping @Sendable (Error) -> Void
    ) {
        let allocSelector = NSSelectorFromString("alloc")
        let initializeSelector = NSSelectorFromString("initWithFlow:")
        let hasNextSelector = NSSelectorFromString(
            "hasNextWithCompletionHandler:"
        )
        let nextSelector = NSSelectorFromString("next")
        let cancelSelector = NSSelectorFromString("cancel")

        guard
            let allocMethod = class_getClassMethod(
                iteratorClass,
                allocSelector
            ),
            let initializeMethod = class_getInstanceMethod(
                iteratorClass,
                initializeSelector
            ),
            let hasNextMethod = class_getInstanceMethod(
                iteratorClass,
                hasNextSelector
            ),
            let nextMethod = class_getInstanceMethod(
                iteratorClass,
                nextSelector
            ),
            let cancelMethod = class_getInstanceMethod(
                iteratorClass,
                cancelSelector
            )
        else {
            return nil
        }

        let allocate = unsafeBitCast(
            method_getImplementation(allocMethod),
            to: Alloc.self
        )
        let initialize = unsafeBitCast(
            method_getImplementation(initializeMethod),
            to: Initialize.self
        )
        let allocated = allocate(iteratorClass, allocSelector)
        iterator = initialize(allocated, initializeSelector, flow)
        hasNext = unsafeBitCast(
            method_getImplementation(hasNextMethod),
            to: HasNext.self
        )
        next = unsafeBitCast(
            method_getImplementation(nextMethod),
            to: Next.self
        )
        cancelIterator = unsafeBitCast(
            method_getImplementation(cancelMethod),
            to: Cancel.self
        )
        self.onValue = onValue
        self.onError = onError
    }

    func start() {
        requestNext()
    }

    func cancel() {
        let shouldCancel = lock.withLock {
            guard !isCancelled else {
                return false
            }
            isCancelled = true
            return true
        }
        if shouldCancel {
            cancelIterator(iterator, NSSelectorFromString("cancel"))
        }
    }

    private func requestNext() {
        guard !lock.withLock({ isCancelled }) else {
            return
        }

        let completion: @convention(block) (NSNumber?, NSError?) -> Void = {
            [weak self] hasNext, error in
            guard let self else {
                return
            }
            DispatchQueue.main.async {
                self.handle(hasNext: hasNext, error: error)
            }
        }
        hasNext(
            iterator,
            NSSelectorFromString("hasNextWithCompletionHandler:"),
            completion
        )
    }

    private func handle(hasNext: NSNumber?, error: NSError?) {
        guard !lock.withLock({ isCancelled }) else {
            return
        }

        if let error {
            if !isCancellation(error) {
                onError(error)
            }
            return
        }
        guard hasNext?.boolValue == true else {
            return
        }

        _ = next(iterator, NSSelectorFromString("next"))
        onValue()
        requestNext()
    }

    private func isCancellation(_ error: NSError) -> Bool {
        if let exception = error.userInfo["KotlinException"] {
            let description = String(reflecting: type(of: exception))
                + " "
                + String(describing: exception)
            return description.contains("CancellationException")
        }
        return false
    }
}
#endif
