public extension KMPState {
    /// Observes a KMP-NativeCoroutines `NativeFlow` directly.
    static func nativeFlow<Output, Failure: Error, Unit>(
        _ keyPath: KeyPath<
            ViewModel,
            KMPNativeFlow<Output, Failure, Unit>
        >
    ) -> Self {
        Self { viewModel, notify, reportError in
            let flow = viewModel[keyPath: keyPath]
            let cancel = flow(
                { _, next, unit in
                    Task { @MainActor in
                        notify()
                    }
                    _ = next()
                    return unit
                },
                { error, unit in
                    if let error {
                        Task { @MainActor in
                            reportError(error)
                        }
                    }
                    return unit
                },
                { _, unit in
                    // Kotlin cancellation is expected lifecycle termination.
                    return unit
                }
            )

            return KMPObservation {
                _ = cancel()
            }
        }
    }

    static func automatic() -> Self
    where ViewModel: KMPNativeObservable {
        .nativeFlow(\.kmpObservationFlow)
    }
}

public extension KMPNativeObservable {
    static var kmpObservationPlan: KMPObservationPlan<Self> {
        KMPObservationPlan(.automatic())
    }

    static func kmpStartObservation(
        on model: Self,
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
