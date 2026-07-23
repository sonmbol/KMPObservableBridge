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
- ``KMPValueProperty``
