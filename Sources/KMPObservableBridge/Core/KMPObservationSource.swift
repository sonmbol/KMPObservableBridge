/// One mutually exclusive observation route selected before a store starts.
///
/// A single route prevents generated and explicit adapters from collecting the
/// same Kotlin state concurrently.
@MainActor
enum KMPObservationSource<ViewModel: AnyObject> {
    case demandDriven
    case staticPlan(KMPObservationPlan<ViewModel>)
    case keyed(
        @MainActor (
            ViewModel,
            @escaping KMPObservationDependencyNotify,
            @escaping KMPObservationErrorHandler
        ) -> KMPObservation
    )
    case explicit([KMPState<ViewModel>])
}

@MainActor
func kmpStaticObservationSource<ViewModel: KMPStaticallyObservable>(
    for _: ViewModel.Type
) -> KMPObservationSource<ViewModel> {
    guard ViewModel.kmpObservationStrategy == .explicit else {
        return .demandDriven
    }
    return .keyed { model, notifyDependency, reportError in
        ViewModel.kmpStartObservation(
            on: model,
            notifyDependency: notifyDependency,
            reportError: reportError
        )
    }
}
