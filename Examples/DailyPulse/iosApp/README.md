# DailyPulse iOS examples

The application is organized by the decision an iOS consumer makes:

```text
iosApp/
├── ContentView.swift
├── Examples/
│   ├── ArticleSKIEExample.swift
│   ├── OwnershipExamples.swift
│   ├── CallbackExamples.swift
│   └── NativeCoroutinesExample.swift
├── Support/
│   ├── KMPInterop.swift
│   ├── SKIEStateFlowInterop.swift
│   ├── BridgeCallbackPublisher.swift
│   └── ExampleStyles.swift
```

## Which example should I open?

| KMP/iOS design | Example |
| --- | --- |
| Macro-declared SKIE `StateFlow` | `ArticleSKIEExample.swift` and `OwnershipExamples.swift` |
| `StateObject`, `ObservedObject`, environment ownership | `OwnershipExamples.swift` |
| Writable Kotlin property as SwiftUI `Binding` | `OwnershipExamples.swift` |
| KMP-NativeCoroutines `NativeFlow` | `NativeCoroutinesExample.swift` |
| Kotlin callback with explicit cancellation | `CallbackExamples.swift` |
| Combine publisher adapter | `CallbackExamples.swift` and `BridgeCallbackPublisher.swift` |
| SKIE value reads and owned-model disposal | `SKIEStateFlowInterop.swift` and `KMPInterop.swift` |

## Example architecture

Each feature demonstrates the same production-friendly boundary:

```text
KMP ViewModel
    ↓ thin bridge container
Native Swift values + Binding + action closures
    ↓
Pure SwiftUI presentation
```

The container owns or observes the Kotlin model and performs synchronous value
projection. The presentation view knows nothing about KMP, SKIE, flows,
collectors, or cancellation. This keeps rendering code reusable and makes
previews deterministic.

Every example includes preview states for the UI it owns, including populated,
loading, empty, callback, Combine, NativeFlow, writable binding, and dark-mode
variants. These previews use immutable Swift fixtures and do not initialize
Koin, allocate Kotlin ViewModels, start coroutines, collect flows, or perform
network requests.

There is no generated Swift source or build-tool plugin. Every ViewModel's
typed observation plan is declared locally with `@KMPObservable`.
