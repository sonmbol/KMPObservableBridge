# ``KMPObservableBridge``

Connect arbitrary Kotlin Multiplatform ViewModels to native SwiftUI ownership
and observation without requiring a Kotlin runtime dependency.

## Overview

Use ``KMPStateObject`` when a view owns a model, ``KMPObservedObject`` for an
external model, and ``KMPEnvironmentObject`` for a projected store injected by
an ancestor.

```swift
@KMPStateObject(
    wrappedValue: ProfileViewModel(),
    state: \.state
)
private var profile
```

Kotlin remains the source of truth. The bridge observes emissions but never
copies state.

For a model that exposes one canonical KMP-NativeCoroutines flow, opt into
automatic observation once:

```swift
extension ProfileViewModel: @retroactive KMPNativeObservable {}

@KMPStateObject
private var profile = ProfileViewModel()
```

The explicit `state:` form remains the universal option. The automatic form
removes the key path without requiring a framework-owned Kotlin superclass.

For SKIE frameworks, the optional `kmp-observable-bridge-generator` executable
can inspect the framework after its Gradle build and generate the
``KMPAutomaticallyObservable`` conformances. Add its generated Swift file to
the application target automatically by passing `--xcode-project` and
`--target`. The initial registration intentionally requires one additional
build because Xcode plans Compile Sources before Run Scripts execute. Later
builds update the generated source without rewriting the project. Projects that
do not run the generator continue using explicit `state:` or `states:`
initializers.

## Topics

### Ownership

- ``KMPStateObject``
- ``KMPObservedObject``
- ``KMPEnvironmentObject``
- ``KMPViewModelStore``
- ``KMPDisposable``

### Child models

- ``KMPChildObject``
- ``KMPOptionalChildObject``

### Observation

- ``KMPState``
- ``KMPObservation``
- ``KMPUpdatePolicy``
- ``KMPObservationFailurePolicy``
- ``KMPNativeObservable``
- ``KMPAutomaticallyObservable``
- ``KMPNativeFlow``
- ``KMPValueProperty``
