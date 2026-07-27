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

There is no generated Swift source or build-tool plugin. Every ViewModel's
typed observation plan is declared locally with `@KMPObservable`.
