# KMPObservableBridge Launch Kit

Attach `Assets/social-preview.png` when announcing the release.

## Short post

KMPObservableBridge 1.0 is available: a lightweight, architecture-neutral way
to observe Kotlin Multiplatform state directly from SwiftUI.

It supports SKIE, KMP-NativeCoroutines, callbacks, Combine, and custom adapters
without requiring a Kotlin superclass, annotation, compiler plugin, or runtime.
It includes SwiftUI-style owned, observed, environment, and child ViewModels,
deterministic cancellation, rebinding, and coalesced updates.

https://github.com/sonmbol/KMPObservableBridge

#KotlinMultiplatform #KMP #SwiftUI #iOSDev #Kotlin

## Reddit

**Title:** KMPObservableBridge 1.0 — observe Kotlin state directly in SwiftUI

I released KMPObservableBridge, a dependency-light Swift package for connecting
Kotlin Multiplatform state to SwiftUI without duplicating state in a Swift
adapter ViewModel.

The goal is architecture neutrality: no required Kotlin base class, annotation,
compiler plugin, or runtime. The same ownership model works with SKIE,
KMP-NativeCoroutines, generated async sequences, callbacks, Combine, and custom
adapters.

The 1.0 API mirrors SwiftUI concepts with `KMPStateObject`,
`KMPObservedObject`, `KMPEnvironmentObject`, and `KMPChildObject`. It handles
cancellation, model rebinding, stale-emission suppression, background
callbacks, observation failures, and hot-stream update coalescing.

Repository, documentation, examples, and tests:
https://github.com/sonmbol/KMPObservableBridge

I would especially value feedback on API ergonomics, Swift concurrency
behavior, and real-world KMP framework integrations.

## Kotlin Slack

I released KMPObservableBridge 1.0, a SwiftUI bridge for KMP state that works
with SKIE, KMP-NativeCoroutines, callbacks, Combine, and custom adapters without
a Kotlin-side dependency or required ViewModel base class. It follows
SwiftUI-style ownership and includes environment/child ViewModels,
deterministic cancellation and rebinding, failure policies, and coalesced
updates. Feedback is welcome:
https://github.com/sonmbol/KMPObservableBridge

## Swift Forums

**Title:** KMPObservableBridge: architecture-neutral Kotlin state observation for SwiftUI

KMPObservableBridge lets SwiftUI observe state exposed by Kotlin Multiplatform
models while Kotlin remains the source of truth. Its API models SwiftUI
ownership instead of introducing a framework-owned Kotlin ViewModel hierarchy.

The package supports async sequences, callbacks, Combine publishers, and custom
adapters, with optional convenience for SKIE and KMP-NativeCoroutines. The core
depends only on Apple system frameworks and supports iOS 14, macOS 11, tvOS 14,
and watchOS 7.

The implementation focuses on actor-safe UI invalidation, deterministic
cancellation and disposal, identity-aware rebinding, stale-emission
suppression, and coalescing for hot streams. Review from developers experienced
with Swift concurrency and cross-language ownership is very welcome.

https://github.com/sonmbol/KMPObservableBridge

## Directory submission

**Name:** KMPObservableBridge

**URL:** https://github.com/sonmbol/KMPObservableBridge

**Description:** A lightweight, architecture-neutral SwiftUI observation bridge
for Kotlin Multiplatform state. Supports StateFlow through SKIE or
KMP-NativeCoroutines, generated async sequences, callbacks, Combine, and custom
adapters without a required Kotlin superclass, annotation, plugin, or runtime.

**Keywords:** Kotlin Multiplatform, KMP, KMM, SwiftUI, StateFlow, coroutines,
Kotlin/Native, SKIE, KMP-NativeCoroutines, Observation, MVVM, MVI
