public extension KMPState {
    internal static func asyncSequences<each Sequence: AsyncSequence>(
        _ keyPaths: repeat KeyPath<ViewModel, each Sequence>
    ) -> [Self] {
        var result: [Self] = []
        for keyPath in repeat each keyPaths {
            result.append(.asyncSequence(keyPath))
        }
        return result
    }

    /// Observes an `AsyncSequence` property, including a SKIE StateFlow.
    static func asyncSequence<Sequence: AsyncSequence>(
        _ keyPath: KeyPath<ViewModel, Sequence>
    ) -> Self {
        asyncSequence(keyPath, everyEmissionFrom: { $0[keyPath: keyPath] })
    }

    /// Observes every emission without equality suppression.
    static func everyEmission<Sequence: AsyncSequence>(
        _ keyPath: KeyPath<ViewModel, Sequence>
    ) -> Self {
        asyncSequence(keyPath)
    }

    /// Observes a sequence and suppresses consecutive equal elements.
    static func equatable<Sequence: AsyncSequence>(
        _ keyPath: KeyPath<ViewModel, Sequence>
    ) -> Self where Sequence.Element: Equatable {
        asyncSequence(keyPath, changes: { $0 })
    }

    /// Invalidates only when a selected value changes.
    static func asyncSequence<
        Sequence: AsyncSequence,
        Selection: Equatable
    >(
        _ keyPath: KeyPath<ViewModel, Sequence>,
        changes select: @escaping @MainActor (Sequence.Element) -> Selection
    ) -> Self {
        Self(dependency: .field(keyPath)) { viewModel, notify, reportError in
            let source = viewModel[keyPath: keyPath]
            let task = Task { @MainActor in
                var previous: Selection?
                var hasPrevious = false

                do {
                    for try await element in source {
                        try Task.checkCancellation()
                        let selection = select(element)
                        guard !hasPrevious || previous != selection else {
                            continue
                        }
                        previous = selection
                        hasPrevious = true
                        notify()
                    }
                } catch is CancellationError {
                    // Expected lifecycle termination.
                } catch {
                    reportError(error)
                }
            }

            return KMPObservation {
                task.cancel()
            }
        }
    }

    /// Invalidates only when the compile-time checked projection changes.
    static func asyncSequence<
        Sequence: AsyncSequence,
        Selection: Equatable
    >(
        _ keyPath: KeyPath<ViewModel, Sequence>,
        changes: KMPChanges<Sequence.Element, Selection>
    ) -> Self {
        asyncSequence(keyPath, changes: changes.select)
    }

    /// Observes an `AsyncSequence` produced by an interop adapter.
    static func asyncSequence<Sequence: AsyncSequence>(
        _ sequence: @escaping @MainActor (ViewModel) -> Sequence
    ) -> Self {
        asyncSequence(nil, everyEmissionFrom: sequence)
    }

    private static func asyncSequence<Sequence: AsyncSequence>(
        _ keyPath: AnyKeyPath?,
        everyEmissionFrom sequence: @escaping @MainActor (ViewModel) -> Sequence
    ) -> Self {
        Self(
            dependency: keyPath.map(KMPObservationDependency.field) ?? .global
        ) { viewModel, notify, reportError in
            let source = sequence(viewModel)
            let task = Task { @MainActor in
                do {
                    for try await _ in source {
                        try Task.checkCancellation()
                        notify()
                    }
                } catch is CancellationError {
                    // Expected lifecycle termination.
                } catch {
                    reportError(error)
                }
            }

            return KMPObservation {
                task.cancel()
            }
        }
    }
}
