/// One mutually exclusive observation route selected before a store starts.
///
/// A single route prevents generated and explicit adapters from collecting the
/// same Kotlin state concurrently.
@MainActor
enum KMPObservationSource<ViewModel: AnyObject> {
    case staticPlan(KMPObservationPlan<ViewModel>)
    case explicit([KMPState<ViewModel>])
}

@MainActor
func kmpStaticObservationSource<ViewModel: KMPStaticallyObservable>(
    for _: ViewModel.Type
) -> KMPObservationSource<ViewModel> {
    .explicit([
        .custom { model, notify, reportError in
            ViewModel.kmpStartObservation(
                on: model,
                notify: notify,
                reportError: reportError
            )
        },
    ])
}
