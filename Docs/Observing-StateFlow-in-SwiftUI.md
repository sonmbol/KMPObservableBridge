# Observing Kotlin StateFlow in SwiftUI Without Adapter ViewModels

Kotlin Multiplatform can share a domain model and presentation state, but the
last step into SwiftUI is often repetitive. Teams create one Swift
`ObservableObject` per screen, collect a Kotlin flow, copy its latest value into
`@Published`, forward every action, and manually align two lifecycle systems.

That adapter works—until navigation, replacement, cancellation, background
callbacks, or a hot stream exposes an ownership mistake.

KMPObservableBridge takes a narrower approach: Kotlin remains the source of
truth and SwiftUI observes the original Kotlin ViewModel.

```swift
@KMPStateObject(
    wrappedValue: ProfileViewModel(),
    state: \.state,
    dispose: { $0.clear() }
)
private var profile
```

The wrapper owns the model for the current SwiftUI identity, observes its state,
invalidates the view on the main actor, and disposes the model exactly once.
There is no shadow state to synchronize.

## The mismatch a bridge must solve

A production bridge needs to answer more than “how do I iterate this flow?”

- Who owns the Kotlin object?
- When does collection begin and end?
- What happens when a parent supplies a different instance?
- Can an emission from the old instance refresh the new view?
- Which executor delivers SwiftUI invalidation?
- Does cancellation cross the Swift/Kotlin boundary?
- Is a stream failure a domain error or observation-infrastructure failure?

KMPObservableBridge models those decisions explicitly. `KMPStateObject` owns a
model, `KMPObservedObject` observes external ownership,
`KMPEnvironmentObject` shares an existing store without another subscription,
and child wrappers rebind by identity without disposing parent-owned children.

## SKIE

SKIE exposes Kotlin `StateFlow` as a Swift `AsyncSequence` and preserves a
synchronous `value`. Add one conformance in the application target—the only
target that can import both the generated framework and the bridge:

```swift
import Shared
import KMPObservableBridge

extension SkieSwiftStateFlow: @retroactive KMPValueProperty {}
```

Then state can be observed through a key path:

```swift
@KMPStateObject(
    wrappedValue: CounterViewModel(),
    states: \.counterState, \.messageState
)
private var counter

Text("\(counter.counterState.count)")
Text(counter.messageState)
```

Dynamic-member lookup forwards nested reads to Kotlin’s current value. A
string-valued state can be passed directly to SwiftUI `Text`.

## KMP-NativeCoroutines

`@NativeCoroutinesState` exposes observation and the current value separately.
KMPObservableBridge can consume the exported NativeFlow signature directly:

```swift
import KMPObservableBridge

@KMPStateObject(
    wrappedValue: ProfileViewModel(),
    state: \.profileStateFlow
)
private var profile

Text(profile.profileStateValue.title)
```

For native SwiftUI-style construction without a state argument, expose one
canonical `kmpObservationFlow` from Kotlin and add an empty retroactive
`KMPNativeObservable` conformance in the application target:

```swift
extension ProfileViewModel: @retroactive KMPNativeObservable {}

@KMPStateObject
private var profile = ProfileViewModel()
```

Use `KMPObservedObject(wrappedValue:)` for the same automatic observation when
the parent owns the model. Rebinding cancels the previous NativeFlow before the
replacement is published, and the observed wrapper never disposes either
model.

The canonical flow aggregates invalidations; Kotlin remains the source of truth
for every value. Cancellation of the bridge observation calls the NativeFlow
cancellable and stops Kotlin collection.

## Loading and errors stay in Kotlin

The bridge should not invent screen state:

```kotlin
data class ProfileState(
    val profile: Profile? = null,
    val isLoading: Boolean = false,
    val error: ProfileError? = null,
)
```

Loading, empty, transient failure, fatal failure, and retry eligibility belong
to the shared state machine. Observation failures—such as a failed adapter—use
a separate bridge failure policy so they cannot masquerade as domain state.

## Hot streams and redraw pressure

The default coalesced update policy sends at most one invalidation per
main-actor turn. Kotlin still owns the latest value, so SwiftUI renders current
state without maintaining a second cache. An immediate policy remains
available when each emission must produce a distinct invalidation.

## Why no required Kotlin superclass?

Requiring a framework ViewModel base class can provide more automation, but it
also makes the shared architecture depend on the UI bridge. KMPObservableBridge
instead accepts async sequences, publishers, callbacks, or custom observation
factories. SKIE and KMP-NativeCoroutines remain optional integration choices.

The unavoidable tradeoff is explicit state key paths. Swift cannot reliably
discover arbitrary generated Kotlin streams without a Kotlin dependency or
generated metadata. Making that boundary visible keeps behavior type-safe and
predictable.

## Try it

The repository includes Swift tests, strict-concurrency validation, a real
generated Kotlin framework, SKIE and KMP-NativeCoroutines integrations, and a
SwiftUI sample:

https://github.com/sonmbol/KMPObservableBridge

Start with one screen, choose ownership deliberately, and keep domain state in
Kotlin. The Swift layer can stay small without making lifecycle behavior vague.
