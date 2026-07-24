# KMPObservableBridge

![KMPObservableBridge — Kotlin State. Native SwiftUI.](Assets/social-preview.png)

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![Kotlin Multiplatform](https://img.shields.io/badge/Kotlin-Multiplatform-7F52FF?logo=kotlin&logoColor=white)](https://kotlinlang.org/docs/multiplatform.html)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-lightgrey)](Package.swift)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

`KMPObservableBridge` lets SwiftUI observe Kotlin Multiplatform ViewModels
without writing a Swift wrapper for every screen. Kotlin remains the source of
truth, and SwiftUI continues calling the real Kotlin ViewModel directly.

**SwiftUI-native KMP state observation for StateFlow, SKIE,
KMP-NativeCoroutines, Combine, callbacks, and custom coroutine adapters.**

The core has no Kotlin-side component, superclass, annotation, compiler plugin,
code generator, or third-party runtime dependency. SKIE StateFlows are
discovered lazily through their exported Objective-C getters; explicit state
key paths remain available when deterministic selection is preferred.

Keywords: SwiftUI, Kotlin Multiplatform, KMP, KMM, StateFlow, coroutines,
Kotlin/Native, iOS, SKIE, KMP-NativeCoroutines, ObservableObject, Observation,
MVVM, MVI.

## Remove the adapter layer

Without a lifecycle-aware bridge, every screen commonly grows another Swift
ViewModel that copies Kotlin state and manually owns collection:

```swift
final class ProfileAdapter: ObservableObject {
    @Published private(set) var state: ProfileState
    private var observation: Task<Void, Never>?

    // Collection, cancellation, error delivery, rebinding, and disposal
    // must remain correct for every screen.
}
```

With KMPObservableBridge, SwiftUI owns or observes the real Kotlin ViewModel:

```swift
@KMPStateObject private var profile = ProfileViewModel()
```

No shadow `@Published` state, duplicated action methods, or screen-specific
adapter object is required.

<p align="center">
  <img src="Assets/demo.png" width="300" alt="DailyPulse running KMPObservableBridge in SwiftUI">
</p>

## The common case

Most screens need one immutable Kotlin `StateFlow`. With SKIE, setup takes
three steps.

### 1. Expose one screen state from Kotlin

```kotlin
data class ProfileState(
    val profile: Profile? = null,
    val isLoading: Boolean = false,
    val error: ProfileError? = null,
)

class ProfileViewModel(
    private val repository: ProfileRepository,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val _state = MutableStateFlow(ProfileState())
    val state: StateFlow<ProfileState> = _state.asStateFlow()

    fun refresh() {
        scope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            _state.value = runCatching { repository.profile() }.fold(
                onSuccess = { ProfileState(profile = it) },
                onFailure = {
                    ProfileState(error = ProfileError.from(it))
                },
            )
        }
    }

    fun clear() {
        scope.cancel()
    }
}
```

Loading, content, empty, and domain-error states should live together in this
immutable state object.

### 2. Add nicer state reads (optional)

Place this in the iOS application target:

```swift
import shared
import KMPObservableBridge

extension SkieSwiftStateFlow: @retroactive KMPValueProperty {}
```

This lets Swift read `viewModel.state.isLoading` instead of
`viewModel.state.value.isLoading`. It does not affect observation, copy state,
or take ownership of anything.

### 3. Own and observe the ViewModel

```swift
struct ProfileScreen: View {
    @KMPStateObject(
        wrappedValue: ProfileViewModel(repository: Dependencies.profile),
        dispose: { $0.clear() }
    )
    private var viewModel

    var body: some View {
        Group {
            if viewModel.state.isLoading {
                ProgressView()
            } else if let error = viewModel.state.error {
                ErrorView(error: error, retry: viewModel.refresh)
            } else if let profile = viewModel.state.profile {
                ProfileContent(profile: profile)
            } else {
                EmptyView()
            }
        }
        .task {
            viewModel.refresh()
        }
    }
}
```

There is no Swift adapter object and no duplicated `@Published` state.
Automatic SKIE observation and the `.coalesced` update policy are the defaults.
Use an explicit `state:` key path for deterministic selection or
`observation: .none` to create no automatic subscription.

## Installation

### Xcode

1. Select **File → Add Package Dependencies…**
2. Enter `https://github.com/sonmbol/KMPObservableBridge.git`.
3. Choose **Up to Next Major Version** from `1.0.0`.
4. Add the `KMPObservableBridge` product to your application target.

Then add `import KMPObservableBridge` to your SwiftUI view.

### Package.swift

```swift
dependencies: [
    .package(
        url: "https://github.com/sonmbol/KMPObservableBridge.git",
        from: "1.0.0"
    ),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(
                name: "KMPObservableBridge",
                package: "KMPObservableBridge"
            ),
        ]
    ),
]
```

The package supports:

- iOS 14+
- macOS 11+
- tvOS 14+
- watchOS 7+
- Swift tools 5.9+

## Which property wrapper should I use?

| Situation | Wrapper | Disposes Kotlin model? |
| --- | --- | --- |
| The view creates the ViewModel | `KMPStateObject` | Only when `dispose` is supplied |
| A parent or DI container owns it | `KMPObservedObject` | Never |
| An ancestor injects `$viewModel` | `KMPEnvironmentObject` | Never |
| A parent owns a child ViewModel | `KMPChildObject` | Never |

### View-owned model

```swift
@KMPStateObject(
    wrappedValue: ProfileViewModel(),
    dispose: { $0.clear() }
)
private var profile
```

The model is created lazily and once per SwiftUI view identity.

### Injector-owned model

```swift
@KMPStateObject(
    injector: AppInjector(),
    viewModel: \.profileViewModel,
    dispose: { $0.clear() }
)
private var profile
```

### Parent-owned model

```swift
struct ProfileContent: View {
    @KMPObservedObject private var profile: ProfileViewModel

    init(viewModel: ProfileViewModel) {
        _profile = KMPObservedObject(viewModel)
    }

    var body: some View {
        Text(profile.state.profile?.name ?? "No profile")
    }
}
```

If the parent supplies a different ViewModel instance, the bridge cancels the
old observation and safely rebinds. It never calls `clear()` on a parent-owned
model.

## Reading state and calling Kotlin

The wrapped value is the real Kotlin ViewModel:

```swift
viewModel.refresh()
viewModel.selectItem(id: item.id)
```

With `KMPValueProperty`, nested state members omit `.value`:

```swift
viewModel.state.isLoading
viewModel.state.profile
```

SwiftUI `Text` also accepts a string-valued property directly:

```swift
Text(viewModel.messageState)
```

The flow itself is still returned when assigning the whole property:

```swift
let flow = viewModel.state
let currentState = viewModel.state.value
```

Swift cannot replace only one property on the Kotlin object while preserving
all of its other methods. `KMPValueProperty` is therefore dynamic-member syntax,
not flow flattening.

## Multiple state streams

Prefer one screen-level state object. When a ViewModel genuinely exposes
multiple independent streams, use the advanced `states:` initializer:

```swift
@KMPStateObject(
    wrappedValue: DashboardViewModel(),
    states: \.contentState, \.connectionState,
    dispose: { $0.clear() }
)
private var dashboard
```

Direct key-path syntax supports any number of heterogeneous streams:

```swift
states: \.content, \.connection, \.permissions, \.syncProgress, \.selection
```

Every emission invalidates the view. Avoid observing streams the view does not
render, especially high-frequency streams. When mixing source kinds or building
a dynamic collection, use the type-erased advanced form:

```swift
adapters:
    .asyncSequence(\.contentState),
    .callback { viewModel, notify, reportError in /* ... */ },
    .publisher { $0.connectionPublisher }
```

## Observation errors versus domain errors

Domain failures—network rejection, validation, authorization, empty results—
belong in Kotlin screen state. Observation failures mean the bridge mechanism
itself failed, such as a throwing Swift adapter:

```swift
@KMPStateObject(
    wrappedValue: ProfileViewModel(),
    state: \.state,
    failurePolicy: .custom { error in
        logger.error("KMP observation failed: \(error)")
    },
    dispose: { $0.clear() }
)
private var profile
```

Cancellation caused by view teardown is expected and is not reported as an
error.

## Lifecycle and disposal

Observation cancellation and ViewModel disposal are different operations:

- Both wrappers automatically cancel their Swift observation.
- `KMPStateObject` optionally invokes `dispose` exactly once.
- `KMPObservedObject` never disposes an externally owned model.
- Kotlin `clear()` should be idempotent; cancelling a `Job` or
  `CoroutineScope` already is.

If another framework owns the Kotlin lifecycle, omit `dispose`.

To remove disposal boilerplate, conform a generated Kotlin base class once:

```swift
extension BaseViewModel: @retroactive KMPDisposable {
    public func dispose() {
        clear()
    }
}
```

All owned conforming subclasses are disposed automatically. An explicit
`dispose` closure takes precedence.

## Environment ViewModels

Inject the existing projected store rather than the raw Kotlin model:

```swift
struct AppRoot: View {
    @KMPStateObject(wrappedValue: SessionViewModel(), state: \.state)
    private var session

    var body: some View {
        HomeView()
            .kmpEnvironmentObject($session)
    }
}

struct HomeView: View {
    @KMPEnvironmentObject private var session: SessionViewModel
}
```

The environment and owner share one store and one set of subscriptions.
Missing stores produce SwiftUI's normal missing-environment-object failure.

## Child ViewModels

The two child wrappers represent different Kotlin contracts, not duplicate
APIs:

| Kotlin child contract | Swift wrapper | Swift value | Observation topology |
|---|---|---|---|
| Synchronous property guaranteed to exist | `KMPChildObject` | `Child` | Re-read during SwiftUI updates and rebind by identity |
| `StateFlow<Child?>` that may emit replacements or `null` | `KMPOptionalChildObject` | `Child?` | Observe the parent flow, then observe the current child |

For a direct parent-owned child that is guaranteed to exist:

```swift
@KMPChildObject(
    parent: parent,
    child: \.detailsViewModel,
    state: \.state
)
private var details
```

For an optional child emitted by a flow conforming to `KMPValueProperty`:

```swift
@KMPOptionalChildObject(
    parent: parent,
    child: \.activeDetails,
    state: \.state
)
private var details
```

Child identity changes cancel old subscriptions before rebinding. The parent
retains lifecycle ownership, so child wrappers never call `dispose()`.

The optional wrapper uses a private `KMPOptionalChildStore` because it manages
two observation levels: the parent flow that selects the child and the selected
child's own state. It handles `nil`, child replacement, stale-emission
suppression, and invalidation forwarding. Combining both public wrappers would
force guaranteed children to become unnecessarily optional because a Swift
property wrapper has one fixed `wrappedValue` type.

## Update policy

`.coalesced` is the default and emits at most once per main-actor turn:

```swift
state: \.state,
updatePolicy: .coalesced
```

Use `.immediate` when every emission must produce a distinct invalidation:

```swift
state: \.state,
updatePolicy: .immediate
```

## Interoperability options

The convenience `state: \.state` initializer accepts any `AsyncSequence`, not
only SKIE.

### How the bridge chooses an observer

The bridge chooses exactly one observation route when it creates the store.
The routes cannot run together:

| Model or initializer | Observation route |
| --- | --- |
| Model conforms to `KMPNativeObservable` | Its canonical NativeFlow |
| `state:`, `states:`, or `adapters:` is supplied | Only those explicit sources |
| `observation: .none` | No observation |
| Ordinary no-state initializer | Automatic SKIE discovery |

This decision happens before any SKIE runtime inspection. A
`KMPNativeObservable` model does not install getter interception or look up a
SKIE iterator. Likewise, an explicit state or adapter never starts automatic
SKIE discovery.

### KMP-NativeCoroutines

KMPObservableBridge understands the exported `NativeFlow` signature directly.
The application does not need `asyncSequence(for:)` or an adapter closure:

```swift
@KMPStateObject(
    wrappedValue: ProfileViewModel(),
    state: \.profileStateFlow
)
private var profile

let state = profile.profileStateValue
```

This direct path keeps the bridge core independent of the NativeCoroutines
Swift package while propagating cancellation to the Kotlin collection.

### Automatic SKIE observation

SKIE users can omit state key paths because `.automaticSKIE` is the default:

```swift
@KMPStateObject
private var profile = ProfileViewModel()

struct DetailView: View {
    @KMPObservedObject private var profile: ProfileViewModel

    init(profile: ProfileViewModel) {
        _profile = KMPObservedObject(profile)
    }
}
```

The explicit spelling remains available:

```swift
@KMPStateObject(observation: .automaticSKIE)
private var profile = ProfileViewModel()
```

KMPObservableBridge installs a guarded Objective-C runtime hook on the Kotlin
ViewModel and lazily observes each `StateFlow` when application code first
reads its getter.

There is no generated file, build script, Swift extension, `$` registration,
or Kotlin bridge dependency. Kotlin/Native does not export property metadata,
so the bridge does not enumerate or invoke properties speculatively. It wraps
eligible Objective-C getters and inspects only values returned by getters the
view naturally accesses. Non-flow values are ignored, repeated reads are
deduplicated, and a getter returning a replacement flow cancels the old
collection before observing the new identity.

Only accessed flows are observed. Explicit `state:` and `states:` remain the
deterministic fallback and let an application intentionally select a subset:

```swift
@KMPStateObject(
    wrappedValue: ProfileViewModel(),
    states: \.profileState, \.permissionsState
)
private var profile
```

#### Automatic SKIE compatibility considerations

Automatic SKIE observation is the convenience default, but the mechanism has
stricter compatibility and debugging tradeoffs than explicit key paths:

- It uses process-wide Objective-C method interception for exported Kotlin
  getters.
- It dynamically calls SKIE's generated `SkieColdFlowIterator` ABI, which SKIE
  does not document as a stable third-party runtime API.
- A future Kotlin/Native or SKIE release may change generated names or method
  signatures.
- Another runtime library could intercept the same getter.
- Only flows whose getters are actually read are observed, so conditional UI
  can establish subscriptions at different times.
- Failures caused by an incompatible generated ABI are harder to diagnose than
  statically typed `AsyncSequence` key paths.

The runtime checks the framework image, protocol, iterator class, and required
selectors before activating. If compatibility cannot be established,
discovery safely does nothing. It never invokes unknown Kotlin getters or
methods merely to inspect a model, deduplicates repeated reads, cancels
replaced flows, and treats lifecycle cancellation as non-failure.

Test the application's Kotlin/SKIE matrix in CI. Use explicit `state:` or
`states:` for maximum production stability, or `.none` to disable automatic
observation entirely. This path applies only to SKIE `StateFlow`;
KMP-NativeCoroutines uses the separate structural `NativeFlow` integration
below.

To use the ownership wrapper without creating any automatic observation,
select `.none` explicitly:

```swift
@KMPStateObject(observation: .none)
private var profile = ProfileViewModel()
```

For an externally owned model, keep the declaration plain and select the
strategy when assigning its backing wrapper:

```swift
@KMPObservedObject private var profile: ProfileViewModel

init(profile: ProfileViewModel) {
    _profile = KMPObservedObject(profile, observation: .none)
}
```

`.none` does not invalidate SwiftUI when Kotlin state changes. It is intended
for models observed by another owner, action-only models, previews, or
intentionally static reads.

### Automatic KMP-NativeCoroutines observation

For KMP-NativeCoroutines, expose one canonical NativeFlow that emits whenever
any UI-facing state changes:

```kotlin
class ProfileViewModel : BaseViewModel() {
    private val _state = MutableStateFlow(ProfileState())

    val stateValue: ProfileState get() = _state.value
    val kmpObservationFlow get() = _state.asNativeFlow(scope)
}
```

Conform the generated model once in the application target:

```swift
import shared
import KMPObservableBridge

extension ProfileViewModel: @retroactive KMPNativeObservable {}
```

That conformance is also the routing signal. The bridge detects the explicit
NativeFlow contract before it considers the SKIE fallback, so
NativeCoroutines models never pay for SKIE runtime discovery.

The property-wrapper call then matches native SwiftUI:

```swift
@KMPStateObject
private var profile = ProfileViewModel()
```

For a model supplied by a parent, use the same contract without transferring
ownership:

```swift
struct ProfileView: View {
    @KMPObservedObject private var profile: ProfileViewModel

    init(profile: ProfileViewModel) {
        _profile = KMPObservedObject(profile)
    }
}
```

`KMPStateObject` owns its model and can invoke `KMPDisposable.dispose()` or an
explicit `dispose:` closure. `KMPObservedObject` only observes and rebinds; it
never disposes an externally owned Kotlin model.

`KMPNativeObservable` does not copy emitted values or turn Kotlin properties
into writable Swift state. Its canonical flow only invalidates SwiftUI; reads
and mutations still go directly to the Kotlin model.

Choose the explicit `state:` form for arbitrary existing models and
KMP-NativeCoroutines models without a canonical observation flow. Automatic
SKIE observation uses lazy getter interception rather than Swift reflection:
`Mirror` cannot enumerate Kotlin/Native computed getters.

`Examples/DailyPulse` compiles both the SKIE and KMP-NativeCoroutines paths
against a generated Kotlin framework.

### Callback or CFlow adapters

```swift
adapters: .callback { viewModel, notify, reportError in
    let handle = viewModel.state.watch(
        onValue: { _ in notify() },
        onError: { error in reportError(error) }
    )

    return KMPObservation {
        handle.close()
    }
}
```

`notify` and `reportError` may be called from any thread. The bridge delivers
SwiftUI invalidation and error handling on the main actor. Cancellation handles
must release their Kotlin callback.

### Combine

```swift
adapters: .publisher { viewModel in
    viewModel.profilePublisher
}
```

Publisher values invalidate SwiftUI. Publisher failures follow
`failurePolicy`.

### Custom adapters

Use `.custom` only when the async-sequence, callback, and publisher factories
cannot represent the integration. It has the same
`(viewModel, notify, reportError) -> KMPObservation` contract as `.callback`.

## Threading and memory guarantees

- SwiftUI invalidation always occurs on the main actor.
- Observation is used automatically on current Apple platforms, with
  `ObservableObject` fallback on older deployment targets.
- Callback notification closures are sendable and safe to invoke from worker
  threads.
- Cancellation is synchronous, main-actor isolated, and idempotent.
- Rebinding suppresses emissions already queued by the previous model.
- Observation closures hold the Swift coordinator weakly.
- Async tasks and Combine subscriptions are cancelled when observation ends.
- The bridge stores no shadow copy of Kotlin state.

An `AsyncSequence` implementation must still cooperate with task cancellation.
A custom callback adapter must close its own handle.

## Migration from the pre-1.0 API

- For one stream, replace
  `states: .asyncSequence(\.state)` with `state: \.state`.
- For any number of async streams, use
  `states: \.firstState, \.secondState`.
- Replace mixed `states: .callback(...)` declarations with
  `adapters: .callback(...)`.
- Replace `onObservationError` with
  `failurePolicy: .custom { error in ... }`.
- Replace removed `.property(\.state)` and `.flow(\.state)` calls with
  `.asyncSequence(\.state)`.
- Remove old `value:` and `as:` arguments; those overloads never stored a Swift
  value.
- Callback and custom adapters receive
  `(viewModel, notify, reportError)`.
- ViewModel types must be reference types so identity changes can be handled
  safely.

## Testing

The package test suite covers:

- Async-sequence emission, completion, failure, and cancellation
- Background callback delivery
- Combine emission and failure
- Idempotent cancellation and automatic token cleanup
- Model rebinding and stale-emission suppression
- Model/coordinator deallocation
- Owned-model disposal
- High-frequency observation
- Parameter-pack state lists and update coalescing
- Environment projection and direct/optional child models
- Modern Observation and legacy `ObservableObject` paths
- Swift strict-concurrency diagnostics

Run:

```shell
swift test
swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
```

## Example project

`Examples/DailyPulse` contains a local Swift Package integration. The package
product includes only `Sources/KMPObservableBridge`; the example application is
not shipped to consumers.

## Used in production

Using KMPObservableBridge in a shipped application? Open a
[Showcase discussion](https://github.com/sonmbol/KMPObservableBridge/discussions)
with your app name, link, and integration. Production users may be listed here
with permission.

Use [Discussions](https://github.com/sonmbol/KMPObservableBridge/discussions)
for integration help and [Issues](https://github.com/sonmbol/KMPObservableBridge/issues)
for reproducible defects. See [CONTRIBUTING.md](CONTRIBUTING.md) before
submitting changes and [SECURITY.md](SECURITY.md) for private vulnerability
reporting.

## License

MIT. See `LICENSE`.
