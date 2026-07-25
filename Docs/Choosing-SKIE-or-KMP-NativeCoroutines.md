# Choosing SKIE or KMP-NativeCoroutines for SwiftUI

SKIE and KMP-NativeCoroutines both make Kotlin coroutine APIs easier to consume
from Swift, but they offer different integration shapes. KMPObservableBridge
supports both without forcing either dependency into the Swift package.

## Quick comparison

| Question | SKIE | KMP-NativeCoroutines |
| --- | --- | --- |
| Typical Swift shape | `StateFlow` as an async sequence with value access | Generated `NativeFlow` callback or async wrappers |
| Shortest bridge syntax | Automatic lazy discovery | `KMPNativeObservable` canonical flow |
| Runtime getter interception | Used by automatic mode | No |
| Explicit typed path available | Yes | Yes |
| Best fit | Teams already standardizing on SKIE | Teams already generating NativeCoroutines APIs |

Neither choice is universally better. Prefer the tool already present in the
application unless a measured limitation justifies migration.

## SKIE: shortest SwiftUI declaration

For compatible generated frameworks:

```swift
@KMPStateObject
private var profile = ProfileViewModel()
```

KMPObservableBridge lazily inspects naturally accessed Kotlin getters. When a
returned value conforms to that framework's exported StateFlow protocol, the
bridge starts the matching SKIE iterator.

This removes per-property registration, but it relies on generated runtime
details. Debug builds log unavailable compatibility, successful getter
discovery, and incompatible iterator method shapes.

Use an explicit key path when deterministic observation is more important than
the shortest declaration:

```swift
@KMPStateObject(
    wrappedValue: ProfileViewModel(),
    state: \.state
)
private var profile
```

## KMP-NativeCoroutines: explicit generated contract

A model can expose one NativeFlow representing its canonical invalidation
stream:

```swift
extension ProfileViewModel: KMPNativeObservable {
    public var kmpObservationFlow: KMPNativeFlow<
        ProfileState,
        Error,
        KotlinUnit
    > {
        profileStateFlow
    }
}
```

Then the same wrapper syntax selects NativeFlow before considering SKIE:

```swift
@KMPStateObject
private var profile = ProfileViewModel()
```

This route performs no Objective-C method interception or SKIE iterator lookup.
Each emission enters the common main-actor, failure-policy, cancellation, and
coalescing store.

The exact exported generic types depend on the generated framework. Follow the
generated NativeFlow signature rather than copying placeholder names from an
example.

## Performance considerations

For SKIE automatic discovery:

- compatible and incompatible runtime descriptors are cached per model class;
- eligible getters perform a small return-value protocol check;
- repeated reads of the same StateFlow identity are deduplicated;
- one active iterator is kept per discovered getter and model.

For NativeFlow:

- there is no getter interception;
- the primary cost is the Kotlin-to-Swift callback for each emission;
- cancellation propagates through the returned NativeFlow cancellation handle.

For both routes, SwiftUI rendering usually costs more than bridge dispatch.
The default `.coalesced` policy batches bursts arriving in one main-actor turn.
Use `.immediate` only when every emission must produce a distinct invalidation.

## Selection guide

Choose automatic SKIE when:

- the application already uses and tests SKIE;
- minimum declaration ceremony is important;
- the Kotlin/SKIE version combination is pinned in CI;
- lazy observation matches the view's access pattern.

Choose explicit SKIE key paths when:

- observation topology must be obvious in code;
- only selected flows should invalidate a screen;
- maximum compile-time guidance is preferred.

Choose KMP-NativeCoroutines when:

- it is already the application's coroutine export strategy;
- a canonical NativeFlow can represent screen invalidation;
- avoiding runtime getter interception is a priority.

Choose a custom adapter when the application already has a stable callback,
Combine, or platform-specific observation contract.

## Validate the decision

Whichever route you choose, test:

1. initial state replay;
2. a later Kotlin emission;
3. background delivery to the main actor;
4. model identity replacement;
5. cancellation when the view/store disappears;
6. ViewModel disposal only by its owner.

The included DailyPulse application builds a generated Kotlin framework with
both SKIE and KMP-NativeCoroutines examples.
