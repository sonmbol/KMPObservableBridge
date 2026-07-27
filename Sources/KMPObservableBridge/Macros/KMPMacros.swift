/// Generates the static observation conformance for one imported KMP
/// ViewModel.
///
/// List the SKIE `StateFlow` properties that drive SwiftUI. The macro expands
/// the concise key paths into statically typed observation routes:
///
/// ```swift
/// @KMPObservable(
///     ProfileViewModel.self,
///     fields: \.profileState, \.permissionsState
/// )
/// extension ProfileViewModel: @retroactive KMPStaticallyObservable {}
/// ```
@attached(member, names: named(kmpObservationPlan), named(kmpStartObservation))
public macro KMPObservable<Model>(
    _ model: Model.Type,
    fields: PartialKeyPath<Model>...
) = #externalMacro(
    module: "KMPObservableBridgeMacros",
    type: "KMPObservableMacro"
)
