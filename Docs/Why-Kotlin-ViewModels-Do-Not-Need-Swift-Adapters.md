# Why Kotlin ViewModels do not need Swift adapter ViewModels

A Kotlin Multiplatform application often starts with one Kotlin ViewModel and
ends up maintaining a second Swift ViewModel for every SwiftUI screen:

```swift
final class ProfileAdapter: ObservableObject {
    @Published private(set) var state: ProfileState

    private let viewModel: ProfileViewModel
    private var observation: Task<Void, Never>?

    init(viewModel: ProfileViewModel) {
        self.viewModel = viewModel
        // Start collection, copy state, deliver on the main actor,
        // handle cancellation, and keep lifecycle ownership correct.
    }
}
```

The adapter is not inherently wrong. It becomes expensive when it exists only
to copy already-modeled Kotlin state into `@Published` properties.

## The hidden responsibilities

A production adapter must answer all of these questions:

- Who owns and disposes the Kotlin ViewModel?
- When does StateFlow collection start and stop?
- What happens when the parent supplies a different ViewModel identity?
- Can a late emission from the previous model update the new screen?
- Are background callbacks delivered safely to SwiftUI?
- Should bursts of emissions trigger one render or many?
- How are observation-mechanism failures separated from domain errors?

Repeating those answers for every screen creates more risk than the property
copying itself.

## Keep Kotlin as the source of truth

KMPObservableBridge gives SwiftUI an observable coordinator while returning the
real Kotlin object to application code:

```swift
@KMPStateObject
private var profile = ProfileViewModel()

var body: some View {
    Text(profile.state.title)
    Button("Refresh") {
        profile.refresh()
    }
}
```

The wrapper owns observation and UI invalidation. It does not replace the
Kotlin ViewModel or duplicate its screen state.

For an externally owned model:

```swift
struct ProfileView: View {
    @KMPObservedObject private var profile: ProfileViewModel

    init(profile: ProfileViewModel) {
        _profile = KMPObservedObject(profile)
    }
}
```

The distinction mirrors SwiftUI:

- `KMPStateObject` owns the model for the view identity.
- `KMPObservedObject` observes a model owned elsewhere.
- `KMPEnvironmentObject` consumes an injected projected store.
- Child wrappers rebind without taking lifecycle ownership from the parent.

## Choose the observation route deliberately

The shortest syntax is useful for compatible SKIE models:

```swift
@KMPStateObject
private var profile = ProfileViewModel()
```

Explicit key paths provide maximum determinism:

```swift
@KMPStateObject(
    wrappedValue: ProfileViewModel(),
    state: \.state
)
private var profile
```

KMP-NativeCoroutines models can provide one canonical NativeFlow through
`KMPNativeObservable`. Callbacks and Combine publishers can use custom
adapters. Every route enters the same lifecycle and invalidation store.

## When a Swift adapter is still appropriate

Keep a Swift adapter when it adds real platform behavior:

- substantial Apple-only presentation state;
- UIKit or AppKit delegation;
- platform-specific permission orchestration;
- a deliberate Swift-facing API boundary;
- transformations that genuinely belong to the Apple client.

The goal is not to ban adapters. It is to stop creating one automatically when
its only job is copying Kotlin state.

## A practical migration

Start with one non-critical screen:

1. Keep one immutable Kotlin screen state.
2. Replace the Swift adapter with `KMPStateObject` or `KMPObservedObject`.
3. Verify initial replay, a later emission, cancellation, and disposal.
4. Compare the removed lifecycle code with the final wrapper declaration.
5. Keep explicit state key paths when deterministic selection is preferable.

For help mapping an existing ViewModel, use the
[integration discussion](https://github.com/sonmbol/KMPObservableBridge/discussions/7).
