import Combine

public extension KMPState {
    /// Observes a Combine publisher derived from the KMP model.
    static func publisher<PublisherType: Publisher>(
        _ publisher: @escaping @MainActor (ViewModel) -> PublisherType
    ) -> Self {
        Self { viewModel, notify, reportError in
            let cancellable = publisher(viewModel).sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        Task { @MainActor in
                            reportError(error)
                        }
                    }
                },
                receiveValue: { _ in
                    Task { @MainActor in
                        notify()
                    }
                }
            )

            return KMPObservation(cancellable)
        }
    }
}
