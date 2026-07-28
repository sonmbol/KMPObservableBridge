# ``KMPObservableBridge``

Connect Kotlin Multiplatform ViewModels directly to SwiftUI with macro-expanded,
compile-time-checked observation plans.

## Overview

Use ``KMPStateObject`` when a view owns a model and ``KMPObservedObject`` for
an externally owned model:

```swift
@KMPStateObject private var profile = ProfileViewModel()
```

The zero-configuration initializer requires a macro-expanded
``KMPStaticallyObservable`` conformance. ``KMPObservationPlan`` entries use
typed key paths and collect exported SKIE `StateFlow` sequences.
Explicit `state:`, `states:`, NativeFlow, callback, Combine, and custom
``KMPState`` adapters remain available without macros.

Hubs are shared per model identity, discard equal consecutive state, and
cancel collection after the last SwiftUI identity releases its lease.

On Observation-capable systems, each key-path-backed projected state has a
separate dependency. Reading `$profile.profileState` does not subscribe that
view evaluation to unrelated fields. Direct model access and adapters without
a key path intentionally use a global dependency. Earlier systems retain the
`ObservableObject` fallback.

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

### Static observation

- ``KMPStaticallyObservable``
- ``KMPObservationPlan``
- ``KMPChanges``
- ``KMPState``
- ``KMPObservation``
- ``KMPUpdatePolicy``
- ``KMPObservationFailurePolicy``
- ``KMPNativeObservable``
- ``KMPNativeFlow``
- ``KMPValueProperty``
