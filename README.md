# KMPObservableBridge

![KMPObservableBridge — Kotlin State. Native SwiftUI.](Assets/social-preview.png)

[![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![CI](https://github.com/sonmbol/KMPObservableBridge/actions/workflows/swift.yml/badge.svg)](https://github.com/sonmbol/KMPObservableBridge/actions/workflows/swift.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

KMPObservableBridge lets SwiftUI observe real Kotlin Multiplatform ViewModels
without shadow Swift ViewModels. Local Swift macros create statically typed
observation plans: no generated source files, selector discovery, swizzling,
Objective-C interception, or undocumented SKIE ABI lookup.

```swift
@KMPStateObject private var profile = ProfileViewModel()
```

Kotlin remains the source of truth. One macro declaration per ViewModel lists
its exported state with ordinary Swift key paths, so a renamed or incompatible
property fails the application build.

## Requirements

- Swift 5.9+
- iOS 15+, macOS 11+, tvOS 14+, or watchOS 7+
- A KMP framework whose `StateFlow` properties are exposed as Swift
  `AsyncSequence`s, such as a framework enhanced by SKIE

## Installation

Add `https://github.com/sonmbol/KMPObservableBridge.git` as a Swift Package and
link exactly the integration used by the application target:

- `KMPObservableBridgeSKIE` for SKIE StateFlows.
- `KMPObservableBridgeNative` for KMP-NativeCoroutines or structural native
  adapters.
- `KMPObservableBridge` only for exporter-neutral explicit APIs.

The native and core products do not expose SKIE factories or SKIE runtime
types.

### Declare each ViewModel

Place the macros in a normal application source file near the feature or
ViewModel integration:

```swift
import shared
import KMPObservableBridgeSKIE

extension SkieSwiftStateFlow: @retroactive KMPValueProperty {}

@KMPObservable(
    ProfileViewModel.self,
    fields: \.profileState, \.permissionsState
)
extension ProfileViewModel: @retroactive KMPStaticallyObservable {}
```

Place this extension beside the feature that owns the ViewModel. If multiple
screens share it, declare the conformance once in a shared integration file.
Declare the `SkieSwiftStateFlow` interoperability conformance once per
application module; it allows the projected store to expose the flow's native
current value without `.value`.
SKIE factories exist only in `KMPObservableBridgeSKIE`; they are not visible
to applications that import `KMPObservableBridgeNative`.

## Usage

Own a ViewModel for the lifetime of a SwiftUI identity:

```swift
struct ProfileScreen: View {
    @KMPStateObject(
        wrappedValue: ProfileViewModel(),
        dispose: { $0.clear() }
    )
    private var profile

    var body: some View {
        ProfileContent(state: $profile.profileState)
    }
}
```

Observe a model owned by a parent or dependency container:

```swift
struct ProfileContent: View {
    @KMPObservedObject private var profile: ProfileViewModel

    init(profile: ProfileViewModel) {
        _profile = KMPObservedObject(profile)
    }
}
```

No lifecycle view modifier is required. `@StateObject` owns the coordinator;
its destruction releases the shared observation lease. This follows
destruction of SwiftUI identity storage, which is intentionally not the same
as visual `onDisappear`.

### Explicit fallback adapters

The macro conformance is not required when the observation source is supplied
explicitly:

```swift
@KMPStateObject(state: \.profileState)
private var profile = ProfileViewModel()

@KMPObservedObject(
    profile,
    states: \.profileState,
    \.permissionsState
)
private var profile
```

`KMPState` also supports KMP-NativeCoroutines flows, Combine publishers,
callbacks, and custom cancellation adapters.

### Native state projection and bindings

The wrapper deliberately keeps the unprojected value as the original Kotlin
object. Its projected store unwraps read-only KMP value containers into native
Swift values:

```swift
Text($profile.messageState)

if $profile.loadingState {
    ProgressView()
}

Text($profile.countState, format: .number)
```

This is a direct synchronous read from the Kotlin container; the bridge does
not cache or duplicate the emitted value. Because the unprojected value remains
the original Kotlin object, actions keep their natural syntax:

```swift
profile.retry()
```

For a genuinely writable exported property, the same projected store creates a
`Binding`:

```swift
TextField("Search", text: $profile.searchText)
```

Read-only StateFlows cannot form a `WritableKeyPath`, so the compiler refuses
to create an unsafe binding. Update immutable screen state through Kotlin
actions:

```swift
Button("Retry") {
    profile.retry()
}
```

The projected store also exposes `rawModel` as an escape hatch for APIs that
need the original imported object.

The projection contract is:

```swift
profile.retry()              // Kotlin action
$profile.messageState        // String
$profile.loadingState        // Bool
$profile.countState          // Int
$profile.searchText          // Binding<String>
$profile.rawModel            // Original Kotlin object
```

### Optional hot-path filtering

Whole emitted-state equality is the normal default. A measured hot screen can
invalidate for only one projection:

```swift
@KMPObservedObject(
    profile,
    state: \.profileState,
    changes: .field(\.isLoading)
)
private var profile
```

### Update policy

`.coalesced` is the default and combines accepted emissions in one main-actor
turn. Event-like streams can opt into `.immediate`.

```swift
@KMPStateObject(updatePolicy: .immediate)
private var profile = ProfileViewModel()
```

## Runtime model

The macro-expanded plan is static metadata. At runtime a main-actor weak registry
keys hubs by `ObjectIdentifier(model)`.

- A model has one collection task per declared flow, even when many views
  observe it.
- Every wrapper holds a lightweight listener lease.
- Consecutive equal values are rejected before wrapper invalidation.
- The last lease cancels every collection task.
- Rebinding cancels the old lease first and generation checks reject stale
  callbacks.
- Owned models are disposed exactly once; observed and environment models are
  never disposed.

On iOS 17+, accepted changes mutate a private Observation revision read during
view evaluation. On iOS 15/16, the same coordinator emits
`objectWillChange`. Collection, equality, coalescing, error handling, and
cancellation are shared.

## Development

```sh
swift test
swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
```

The DailyPulse app is the end-to-end fixture. CI builds its real SKIE
framework, expands the feature-local observation macros, compiles the iOS
target, and audits production sources for Objective-C interception APIs.

## License

KMPObservableBridge is available under the [MIT License](LICENSE).
