# KMPObservableBridge Launch Kit

Use [`Assets/social-preview.png`](Assets/social-preview.png) for link previews
and [`Assets/demo.gif`](Assets/demo.gif) when the channel supports animation.
Keep every announcement technical, specific, and open to critical feedback.

## Core message

KMPObservableBridge 1.1.0 lets SwiftUI observe Kotlin Multiplatform ViewModels
without duplicating business state in a Swift adapter. Kotlin remains the
source of truth, while SwiftUI gets explicit ownership, lifecycle-safe
collection, field-level Observation on supported platforms, and native
bindings for writable exports.

The package:

- Supports SKIE, KMP-NativeCoroutines, callbacks, Combine, and custom adapters.
- Requires no Kotlin superclass or runtime dependency in the Swift package.
- Uses explicit, compiler-checked macro fields instead of runtime reflection.
- Shares macro-configured collectors across wrappers for the same model.
- Supports iOS 15, macOS 11, tvOS 14, watchOS 7, and Swift 5.9 or later.

Repository: https://github.com/sonmbol/KMPObservableBridge

Release: https://github.com/sonmbol/KMPObservableBridge/releases/tag/1.1.0

## Short launch post

KMPObservableBridge 1.1.0 is available.

It connects Kotlin Multiplatform ViewModels to SwiftUI without a duplicate
Swift adapter or a Kotlin-side framework dependency. Kotlin stays authoritative;
SwiftUI gets familiar ownership wrappers, deterministic cancellation, rebinding,
and field-level dependency tracking for explicitly selected SKIE StateFlows.

It also supports KMP-NativeCoroutines, callbacks, Combine, and custom adapters.
The repository includes a real Gradle → SKIE → Xcode example, benchmarks, and
strict-concurrency tests.

I’m looking for two teams willing to evaluate it on one non-critical screen.
Critical feedback is welcome:

https://github.com/sonmbol/KMPObservableBridge

#KotlinMultiplatform #KMP #SwiftUI #iOSDev #Kotlin

## LinkedIn / X

Using a Kotlin Multiplatform ViewModel in SwiftUI should not require duplicating
its state in a Swift adapter.

```swift
@KMPObservable(
    ArticleViewModel.self,
    fields: \.articleState
)
extension ArticleViewModel: @retroactive KMPStaticallyObservable {}

@KMPStateObject
private var viewModel = ArticleViewModel()
```

Kotlin remains the source of truth. SwiftUI receives explicit ownership,
field-level dependency tracking, deterministic cancellation, and native
bindings for writable exports.

KMPObservableBridge 1.1.0 supports SKIE, KMP-NativeCoroutines, callbacks,
Combine, and custom adapters:

https://github.com/sonmbol/KMPObservableBridge

How are you connecting StateFlow to SwiftUI today?

#KotlinMultiplatform #SwiftUI #KMP #iOSDev

## Reddit

**Title:** KMPObservableBridge 1.1.0 — field-aware Kotlin state observation for SwiftUI

I built KMPObservableBridge to remove the duplicate Swift adapter ViewModel that
often appears between Kotlin state and SwiftUI.

The bridge keeps Kotlin as the only business-state store. For SKIE, an attached
macro creates a compile-time-checked observation plan from explicit StateFlow
key paths. On Observation-capable platforms, projected field reads can track a
specific field; direct model reads retain safe global invalidation behavior.
Older OS versions fall back to `ObservableObject`.

The package also supports KMP-NativeCoroutines, callbacks, Combine, and custom
adapters. Ownership is explicit through SwiftUI-style wrappers, collectors are
cancelled deterministically, stale emissions are suppressed after rebinding,
and macro-configured wrappers share collection for the same model.

There is no Kotlin base class, runtime reflection, or duplicated Swift value
store. The repository includes tests, benchmarks, DocC, and a real
Gradle → SKIE → Xcode example.

Repository and demo:
https://github.com/sonmbol/KMPObservableBridge

I would value critical feedback on the API, Observation semantics, and
cross-language lifecycle model. I’m also offering hands-on help to two teams
that want to evaluate one non-critical screen.

## Kotlin Slack / community Discord

I released KMPObservableBridge 1.1.0, a SwiftUI bridge for KMP ViewModels that
keeps Kotlin state authoritative. It supports SKIE with explicit,
compiler-checked fields, plus KMP-NativeCoroutines, callbacks, Combine, and
custom adapters. There is no required Kotlin superclass or Swift-side state
copy. The project focuses on SwiftUI ownership, field-aware invalidation,
deterministic cancellation, and safe rebinding.

I’m looking for two teams to evaluate one non-critical screen, and I’m happy to
help with the lifecycle review:
https://github.com/sonmbol/KMPObservableBridge

## Swift Forums

**Title:** KMPObservableBridge: field-aware Kotlin state observation for SwiftUI

KMPObservableBridge lets SwiftUI observe exported Kotlin Multiplatform models
while Kotlin remains the authoritative state store.

The core design uses SwiftUI-style ownership wrappers and explicit observation
adapters. The SKIE integration uses an attached macro with compiler-checked
StateFlow key paths. Projected field reads participate in field-level
Observation on supported Apple platforms, while direct model access remains a
safe global dependency. iOS 15/16 retain `ObservableObject` invalidation.

The package also supports KMP-NativeCoroutines, callbacks, Combine, and custom
adapters. It does not require a Kotlin base class, Objective-C reflection, or a
duplicated Swift value cache.

Review from developers experienced with Swift Observation, concurrency,
Kotlin/Native ownership, and macro APIs would be especially useful:
https://github.com/sonmbol/KMPObservableBridge

## Newsletter pitch

**Subject:** Project submission: KMPObservableBridge 1.1.0

KMPObservableBridge is a Swift package for connecting Kotlin Multiplatform
ViewModels to SwiftUI without duplicating business state in a Swift adapter.
It provides SwiftUI-style ownership, explicit compiler-checked SKIE fields,
field-level Observation on supported platforms, deterministic cancellation,
and safe model rebinding. Separate integrations support SKIE and
KMP-NativeCoroutines, while the core also accepts callbacks, Combine, and
custom adapters. The repository includes a real Gradle → SKIE → Xcode example,
strict-concurrency tests, benchmarks, DocC, and an architectural evaluation
guide.

Repository: https://github.com/sonmbol/KMPObservableBridge

Release: https://github.com/sonmbol/KMPObservableBridge/releases/tag/1.1.0

## Thirty-day publishing plan

| Timing | Channel | Goal |
| --- | --- | --- |
| Day 1 | GitHub Discussion | Explain 1.1.0 and invite technical review |
| Day 2–3 | Kotlin Slack / KMP Discord | Ask how teams currently bridge StateFlow |
| Day 4–5 | Reddit | Share the architecture and demo; request criticism |
| Week 2 | Swift Forums | Seek Observation and concurrency review |
| Week 2 | Five personalized maintainer messages | Recruit two pilot integrations |
| Week 3 | Issue or Discussion follow-ups | Publish answers and integration findings |
| Week 4 | GitHub traffic and adopter review | Refine onboarding using measured drop-off |

Do not send bulk unsolicited messages, manufacture testimonials, or claim
production adoption without the application owner’s explicit permission.
