import Combine

public extension KMPState {
    /// Observes a publisher property with field-level dependency tracking.
    ///
    /// The defaulted second parameter keeps existing `.publisher(\.state)`
    /// source syntax while preserving the original closure overload.
    static func publisher<PublisherType: Publisher>(
        _ keyPath: KeyPath<ViewModel, PublisherType>,
        tracksFieldDependency: Bool = true
    ) -> Self {
        makePublisherState(
            dependency: tracksFieldDependency ? .field(keyPath) : .global,
            publisher: { $0[keyPath: keyPath] }
        )
    }

    /// Observes a Combine publisher derived from the KMP model.
    static func publisher<PublisherType: Publisher>(
        _ publisher: @escaping @MainActor (ViewModel) -> PublisherType
    ) -> Self {
        makePublisherState(dependency: .global, publisher: publisher)
    }

    private static func makePublisherState<PublisherType: Publisher>(
        dependency: KMPObservationDependency,
        publisher: @escaping @MainActor (ViewModel) -> PublisherType
    ) -> Self {
        Self(dependency: dependency) { viewModel, notify, reportError in
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
