# Choosing SKIE or KMP-NativeCoroutines for SwiftUI

SKIE and KMP-NativeCoroutines expose Kotlin coroutine APIs to Swift in different
shapes. KMPObservableBridge isolates their APIs in separate package products so
an application can choose its existing export strategy without leaking the
other integration into source or binaries.

## Quick comparison

| Question | SKIE | KMP-NativeCoroutines |
| --- | --- | --- |
| Typical Swift shape | Typed `AsyncSequence` with synchronous StateFlow value access | Generated `NativeFlow` callback or async wrapper |
| Bridge product | `KMPObservableBridgeSKIE` | `KMPObservableBridgeNative` |
| Configuration | Explicit macro fields or wrapper key paths | Explicit NativeFlow key path |
| Field-level dependency metadata | Yes, for macro-configured StateFlows | Global unless a custom keyed adapter provides metadata |
| Runtime reflection | None | None |
| Best fit | Teams already using SKIE | Teams already generating NativeCoroutines APIs |

Neither exporter is universally better. Prefer the one already validated in the
application unless a measured limitation justifies migration.

## SKIE

Declare current-value interoperability once in the application module:

```swift
import shared
import KMPObservableBridgeSKIE

extension SkieSwiftStateFlow: @retroactive KMPValueProperty {}
```

Then declare the StateFlows that form a ViewModel’s observation plan:

```swift
@KMPObservable(
    ProfileViewModel.self,
    fields: \.profileState, \.permissionsState
)
extension ProfileViewModel: @retroactive KMPStaticallyObservable {}
```

The macro expands these compiler-checked key paths into the static observation
plan. Swift macros cannot inspect members of an imported Kotlin type, so fields
are intentionally explicit. The bridge does not use Objective-C discovery,
getter interception, or generated application source.

Own or observe the model normally:

```swift
@KMPStateObject
private var profile = ProfileViewModel()

Text($profile.profileState.title)
```

Use an explicit wrapper adapter when a conformance should remain local to one
use site:

```swift
@KMPStateObject(state: \.profileState)
private var profile = ProfileViewModel()
```

## KMP-NativeCoroutines

Link `KMPObservableBridgeNative` and observe the generated NativeFlow explicitly:

```swift
import shared
import KMPObservableBridgeNative

@KMPStateObject(
    state: \.kmpObservationFlow,
    updatePolicy: .immediate
)
private var example = BridgeExampleViewModel()
```

The NativeFlow is the notification and cancellation source. Render the
separately exported current property:

```swift
Text(example.nativeMessageValue)
```

The exact generated property and generic types depend on the Kotlin declaration
and NativeCoroutines version. Use the generated Swift interface as the contract.

## Performance and rendering behavior

For macro-configured SKIE:

- One static hub shares the model’s configured collectors across wrappers.
- Consecutive equal StateFlow values are suppressed.
- Projected field reads can register field-level dependencies on
  Observation-capable platforms.
- Direct model reads retain global invalidation semantics.

For NativeFlow:

- The Kotlin-to-Swift callback crosses to `MainActor` once.
- Cancellation propagates through the generated cancellation handle.
- The adapter invalidates globally unless it supplies a known dependency key.

For both routes, `.coalesced` unions changes in one main-actor turn.
`.immediate` preserves every accepted emission when that semantic is required.
Neither route duplicates Kotlin business state in Swift.

## Selection guide

Choose SKIE when:

- the application already uses and tests SKIE;
- synchronous StateFlow value access is useful to rendering;
- explicit macro fields fit the project’s feature organization;
- field-aware Observation is valuable.

Choose KMP-NativeCoroutines when:

- it is already the application’s coroutine export strategy;
- a generated NativeFlow provides the desired invalidation contract;
- state is exposed separately through a current-value property.

Choose callbacks, Combine, or a custom adapter when the application already has
a stable platform-specific contract that is easier to validate than migrating
exporters.

## Validate either decision

Test:

1. Initial value rendering.
2. A later Kotlin emission.
3. Foreign-thread delivery to `MainActor`.
4. Model identity replacement and stale-emission suppression.
5. Cancellation when the wrapper’s identity ends.
6. Disposal by owners only.
7. Multiple wrappers and their expected collector count.
8. Equal emissions and body-evaluation counts.

The DailyPulse example builds a real Kotlin framework and demonstrates both
integration products.
