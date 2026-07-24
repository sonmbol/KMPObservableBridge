# ``KMPObservableBridge``

Connect arbitrary Kotlin Multiplatform ViewModels to native SwiftUI ownership
and observation without requiring a Kotlin runtime dependency.

## Overview

Use ``KMPStateObject`` when a view owns a model, ``KMPObservedObject`` for an
external model, and ``KMPEnvironmentObject`` for a projected store injected by
an ancestor.

```swift
@KMPStateObject private var profile = ProfileViewModel()
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

For SKIE frameworks, `.automaticSKIE` is the default and lets wrappers lazily
discover public StateFlows when their exported getters are naturally read.
This requires no generated file or build script, but uses Objective-C method
interception and SKIE's generated iterator ABI. The explicit `state:` and
`states:` initializers remain available for maximum stability and selecting a
specific subset; `.none` disables automatic observation.

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
- ``KMPAutomaticObservation``
- ``KMPNativeObservable``
- ``KMPAutomaticallyObservable``
- ``KMPNativeFlow``
- ``KMPValueProperty``
