/// Enables demand-driven observation for an imported KMP ViewModel.
///
/// A collector starts lazily the first time a projected StateFlow property is
/// read and is shared by all stores observing the same model and key path.
///
/// ```swift
/// @KMPObservable
/// extension ProfileViewModel: @retroactive KMPStaticallyObservable {}
/// ```
@attached(member, names: named(kmpObservationStrategy), named(kmpObservationPlan), named(kmpStartObservation))
public macro KMPObservable() = #externalMacro(
    module: "KMPObservableBridgeMacros",
    type: "KMPObservableMacro"
)

/// Generates an eager static observation plan for an imported KMP ViewModel.
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
