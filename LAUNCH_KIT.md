# KMPObservableBridge Launch Kit

Attach `Assets/social-preview.png` when announcing the release.

## Demo video storyboard

Record one 20–40 second clip in a 16:9 layout:

1. Show a Kotlin `StateFlow` changing in the DailyPulse ViewModel.
2. Show the SwiftUI screen updating in the simulator.
3. Show the removed Swift adapter boilerplate.
4. End on:

   ```swift
   @KMPStateObject
   private var profile = ProfileViewModel()
   ```

Use the caption: **Kotlin State. Native SwiftUI. No duplicate adapter
ViewModel.**

Export an MP4 for LinkedIn, X, Reddit, and Discord, plus a short GIF for the
README and GitHub Release.

## Short post

KMPObservableBridge 1.0.1 is available: a lightweight, architecture-neutral way
to observe Kotlin Multiplatform state directly from SwiftUI.

It supports SKIE, KMP-NativeCoroutines, callbacks, Combine, and custom adapters
without requiring a Kotlin superclass, annotation, compiler plugin, generated
registration, or third-party runtime dependency in the Swift package.
It includes SwiftUI-style owned, observed, environment, and child ViewModels,
deterministic cancellation, rebinding, and coalesced updates.

https://github.com/sonmbol/KMPObservableBridge

#KotlinMultiplatform #KMP #SwiftUI #iOSDev #Kotlin

## Reddit

**Title:** KMPObservableBridge 1.0.1 — observe Kotlin state directly in SwiftUI

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

How does your project currently connect StateFlow to SwiftUI: a manual adapter,
SKIE, KMP-NativeCoroutines, or something else? I would especially value
feedback on API ergonomics, Swift concurrency behavior, and real-world KMP
framework integrations.

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

## LinkedIn / X

Using Kotlin Multiplatform ViewModels in SwiftUI often creates a second Swift
adapter ViewModel for every screen.

KMPObservableBridge removes that layer:

```swift
@KMPStateObject
private var profile = ProfileViewModel()
```

Kotlin remains the source of truth. SwiftUI keeps native ownership,
invalidation, cancellation, rebinding, and lifecycle behavior. It supports
SKIE, KMP-NativeCoroutines, explicit async sequences, callbacks, and Combine.

How are you connecting StateFlow to SwiftUI today?

https://github.com/sonmbol/KMPObservableBridge

#KotlinMultiplatform #KMP #SwiftUI #iOSDev

## Directory submission

**Name:** KMPObservableBridge

**URL:** https://github.com/sonmbol/KMPObservableBridge

**Description:** A lightweight, architecture-neutral SwiftUI observation bridge
for Kotlin Multiplatform state. Supports StateFlow through SKIE or
KMP-NativeCoroutines, generated async sequences, callbacks, Combine, and custom
adapters without a required Kotlin superclass, annotation, plugin, or runtime.

**Keywords:** Kotlin Multiplatform, KMP, KMM, SwiftUI, StateFlow, coroutines,
Kotlin/Native, SKIE, KMP-NativeCoroutines, Observation, MVVM, MVI

## Newsletter pitch

**Subject:** Project submission: KMPObservableBridge 1.0.1

KMPObservableBridge is a Swift package that lets SwiftUI observe real Kotlin
Multiplatform ViewModels without a duplicate Swift adapter per screen. It
supports automatic SKIE StateFlow discovery, KMP-NativeCoroutines, typed async
sequence key paths, callbacks, and Combine while keeping lifecycle ownership
explicit. The repository includes strict-concurrency tests, Apple-platform CI,
DocC, benchmarks, and a generated Kotlin/SKIE example application.

Repository: https://github.com/sonmbol/KMPObservableBridge

Release: https://github.com/sonmbol/KMPObservableBridge/releases/tag/1.0.1

## Seven-day publishing schedule

| Day | Channel | Asset | Goal |
| --- | --- | --- | --- |
| 1 | GitHub Release | Release notes + demo | Give visitors a stable landing page |
| 2 | Kotlin Slack / KMP Discord | Short post | Ask about existing StateFlow patterns |
| 3 | Reddit | Technical post + demo | Invite API and integration feedback |
| 4 | GitHub Discussions | Integration thread | Help one real ViewModel integration |
| 5 | Swift Forums | Architecture post | Reach Swift concurrency reviewers |
| 6 | Five maintainers | Personalized message | Recruit first adopters |
| 7 | GitHub Traffic | Referrals and clones | Refine the best-performing message |
