# Evaluating KMPObservableBridge

This guide helps a team decide whether KMPObservableBridge fits its KMP and
SwiftUI architecture. It is a decision guide, not a claim that one integration
style is universally best.

## Choose this bridge when

- Kotlin ViewModels intentionally own state consumed by SwiftUI.
- The iOS team wants explicit SwiftUI-style ownership.
- Kotlin must remain the single source of truth.
- SKIE, KMP-NativeCoroutines, callbacks, Combine, or mixed adapters are in use.
- Field-level dependencies on Observation-capable platforms matter.
- The project wants compiler-checked key paths instead of runtime discovery.
- Ownership, rebinding, cancellation, and disposal need one consistent model.

## Prefer ordinary SwiftUI state when

- KMP shares only domain, networking, persistence, or use-case code.
- Presentation state is intentionally platform-specific.
- A Swift ViewModel already owns the screen's state and lifetime.
- The application does not export asynchronous Kotlin state to iOS.

Adding a bridge where there is no cross-language presentation-state boundary
creates complexity without a corresponding benefit.

## Architectural comparison

| Question | KMPObservableBridge | Kotlin-integrated ViewModel bridge | Manual Swift adapter |
| --- | --- | --- | --- |
| Kotlin dependency | None required by the core bridge | Usually requires Kotlin-side library APIs | None |
| SwiftUI ownership | Explicit owning, observed, and environment wrappers | Defined by that library's integration | Defined by each adapter |
| State authority | Kotlin | Kotlin | Often duplicated in Swift |
| Discovery | Explicit compile-time Swift key paths | Kotlin-side primitives or metadata | Hand-written subscriptions |
| Reflection | None | Implementation-dependent | None required |
| Collector sharing | Static macro plans share per model identity | Implementation-dependent | Must be designed per adapter |
| Field dependencies | Projected keyed fields on modern Observation platforms | Depends on Kotlin/Swift registrar integration | Depends on adapter design |
| Exporters | SKIE, NativeCoroutines, callbacks, Combine, custom | Usually a selected ecosystem | Any source handled manually |
| Swift boilerplate | One observation declaration per imported model | Kotlin integration plus Swift wrappers | One adapter ViewModel per screen or feature |

The relevant comparison is not the number of API types. Evaluate who owns
state, how dependencies are registered, when collectors start and stop, and
whether the architecture adds another business-state copy.

## Important distinctions

### SKIE

SKIE StateFlow wrappers provide both asynchronous iteration and synchronous
current-value access. `KMPValueProperty` enables projected reads through the
bridge store:

```swift
let message: String = $profile.messageState
```

### KMP-NativeCoroutines

NativeFlow is an observation and cancellation source, not a synchronous value
container. Observe the flow explicitly and read the separately exported
current value:

```swift
@KMPStateObject(
    state: \.kmpObservationFlow,
    updatePolicy: .immediate
)
private var profile = ProfileViewModel()

Text(profile.nativeMessageValue)
```

### Direct and projected reads

`profile.state` reads the original Kotlin model and registers a global model
dependency. `$profile.state` passes through the projected store and can
register a field dependency when the export conforms to `KMPValueProperty`.

## Low-risk evaluation

Start with one non-critical screen:

1. Select one Kotlin ViewModel and one exported state stream.
2. Declare the state with `@KMPObservable` or configure it explicitly at the
   property wrapper.
3. Keep the bridge in a thin live container.
4. Pass Swift values, bindings, and action closures to a pure SwiftUI
   presentation view.
5. Verify construction count, collector count, cancellation, rebinding, and
   disposal in the real navigation hierarchy.
6. Profile body evaluation and allocations before expanding adoption.

## Migration from a manual Swift adapter

Given an adapter that copies Kotlin state:

```swift
final class ProfileAdapter: ObservableObject {
    @Published var state: ProfileState
    let model: ProfileViewModel
}
```

migrate incrementally:

1. Keep the existing presentation view unchanged.
2. Replace the adapter owner with `KMPStateObject`.
3. Feed the presentation view from `$profile.profileState`.
4. Forward actions directly from the Kotlin model.
5. Remove copied Swift state only after lifecycle and rendering tests pass.

The target boundary becomes:

```text
Kotlin ViewModel
    ↓ thin observation container
Swift values + Binding + action closures
    ↓
Pure SwiftUI presentation
```

## Evidence to collect

- Kotlin ViewModel construction and disposal counts.
- Underlying collector counts with parent, child, and environment consumers.
- SwiftUI body evaluations for independent fields.
- Cancellation behavior after navigation and model replacement.
- Weak-reference release across Swift ARC and Kotlin GC boundaries.
- Immediate and coalesced delivery measurements.

Share results in
[GitHub Discussions](https://github.com/sonmbol/KMPObservableBridge/discussions)
or report a reproducible problem through
[GitHub Issues](https://github.com/sonmbol/KMPObservableBridge/issues).
