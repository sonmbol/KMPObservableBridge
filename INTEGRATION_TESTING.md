# Integration testing

The core package intentionally imports no generated KMP module. Interoperability
is validated at two levels.

## Generated framework fixture

`Examples/DailyPulse` builds a real Kotlin/Native framework with SKIE and
KMP-NativeCoroutines. Its iOS application compiles:

- SKIE `StateFlow` async sequences and current values
- A direct NativeFlow key path and automatic `KMPNativeObservable` observation
- NativeFlow cancellation through the Swift observation token
- Multiple heterogeneous flows
- Callback/CFlow-style cancellation handles
- Combine adapters
- Owned, observed, and environment ViewModels
- Automatic `KMPDisposable` lifecycle integration

Run with Java 17:

```shell
cd Examples/DailyPulse
JAVA_HOME=$(/usr/libexec/java_home -v 17) \
  ./gradlew :shared:linkDebugFrameworkIosSimulatorArm64
cd iosApp
xcodebuild build \
  -project iosApp.xcodeproj \
  -scheme iosApp \
  -destination 'generic/platform=iOS Simulator'
```

## Core contract fixtures

The Swift test target validates the contracts used by raw callback wrappers,
KMP-NativeCoroutines NativeFlow, async sequences, and Combine without making
those libraries package dependencies. Every path enters the same lifecycle,
generation-checking, failure-policy, and main-actor invalidation store.

When adding a version-specific integration job, pin its Kotlin and plugin
versions in a separate example project. Do not add those dependencies to the
core package.
