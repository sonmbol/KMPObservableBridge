# KMPObservableBridge Architecture Review

#### 1. 🔍 Code Smell / Issue Analysis
- **Location:** `KMPObservedObject.swift` / external ownership
- **Severity:** Critical
- **The Problem:** The original wrapper stored an externally owned model in a
  `StateObject` forever. When a parent supplied a replacement model, SwiftUI
  continued rendering and observing the first object.

#### 2. 💡 The Perfect Structural Solution
Use reference identity, retain stable coordinator storage, and rebind it during
`DynamicProperty.update()`. Rebinding cancels old subscriptions before changing
the model and uses a generation guard to suppress already-enqueued emissions.

#### 3. 🚀 Refactored Code Implementation
The complete implementation is in
`Sources/KMPObservableBridge/KMPObservedObject.swift` and
`Sources/KMPObservableBridge/KMPViewModelStore.swift`.

---

#### 1. 🔍 Code Smell / Issue Analysis
- **Location:** `KMPObservation` / cancellation lifecycle
- **Severity:** Critical
- **The Problem:** Cancellation was repeatable, was not performed when a token
  was independently released, and had no actor contract. Callback handles could
  therefore be closed multiple times or survive longer than their bridge.

#### 2. 💡 The Perfect Structural Solution
Make the token main-actor isolated, consume its cancellation closure exactly
once, and synchronously cancel from `deinit`.

#### 3. 🚀 Refactored Code Implementation
The complete token implementation is in
`Sources/KMPObservableBridge/KMPObservation.swift`.

---

#### 1. 🔍 Code Smell / Issue Analysis
- **Location:** `KMPState.property` overload family
- **Severity:** Major
- **The Problem:** The `value:` and `as:` parameters were ignored. The API
  promised shadow-value storage and flattening that never occurred, creating
  false type-safety and stale-state expectations.

#### 2. 💡 The Perfect Structural Solution
Remove dishonest overloads. Keep only factories that describe actual runtime
behavior: async sequence, callback, publisher, and custom observation. Kotlin
remains the sole state owner.

#### 3. 🚀 Refactored Code Implementation
The complete replacement API and migration map are in
the focused `KMP*State.swift` adapter files and `README.md`.

---

#### 1. 🔍 Code Smell / Issue Analysis
- **Location:** AsyncSequence and Combine observation / failures
- **Severity:** Major
- **The Problem:** A thrown async sequence triggered an ordinary view refresh,
  while Combine failures were discarded. Infrastructure failure was
  indistinguishable from valid state and impossible to diagnose.

#### 2. 💡 The Perfect Structural Solution
Route non-cancellation failures to an explicit observation error handler.
Treat cancellation as expected lifecycle termination and keep domain failures
inside the Kotlin state machine.

#### 3. 🚀 Refactored Code Implementation
The complete sequence and publisher implementations are in
`KMPAsyncSequenceState.swift` and `KMPPublisherState.swift`; the Kotlin state contract is in
`README.md`.

---

#### 1. 🔍 Code Smell / Issue Analysis
- **Location:** Cross-thread callback and publisher delivery
- **Severity:** Critical
- **The Problem:** Adapter callbacks may originate on Kotlin worker threads.
  Direct Combine/SwiftUI invalidation from those callbacks violates
  `ObservableObject`'s UI isolation and can race teardown or rebinding.

#### 2. 💡 The Perfect Structural Solution
Expose sendable notification closures that are safe to invoke from any thread,
then marshal invalidation and error delivery onto the main actor. Check the
observation generation after hopping actors.

#### 3. 🚀 Refactored Code Implementation
The complete delivery pipeline is in
`Sources/KMPObservableBridge/KMPViewModelStore.swift`, with a background-thread
regression test in `Tests/KMPObservableBridgeTests`.

---

#### 1. 🔍 Code Smell / Issue Analysis
- **Location:** `KMPStateObject` / Kotlin lifecycle
- **Severity:** Major
- **The Problem:** Owning and observing wrappers had no lifecycle distinction.
  A Kotlin coroutine scope could outlive its SwiftUI owner, while automatically
  clearing a parent-owned model would be equally incorrect.

#### 2. 💡 The Perfect Structural Solution
Allow only the owning wrapper to accept an explicit disposer. Invoke it exactly
once after observations are cancelled. The externally owned wrapper only
cancels subscriptions.

#### 3. 🚀 Refactored Code Implementation
The complete ownership API is in
`Sources/KMPObservableBridge/KMPStateObject.swift` and
`Sources/KMPObservableBridge/KMPObservedObject.swift`; Kotlin `clear()` usage is
documented in `README.md`.
