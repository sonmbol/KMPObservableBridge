# Integration testing

The core package intentionally imports no generated KMP module. Interoperability
is validated at two levels.

## Generated framework fixture

`Examples/DailyPulse` builds a real Kotlin/Native framework with SKIE. Its iOS
application compiles:

- SKIE `StateFlow` async sequences and current values
- Multiple heterogeneous flows
- Callback/CFlow-style cancellation handles
- Combine adapters
- Owned, observed, and environment ViewModels
- Automatic `KMPDisposable` lifecycle integration

Run with Java 17:

```shell
cd Examples/DailyPulse
./gradlew :shared:linkDebugFrameworkIosSimulatorArm64
cd iosApp
xcodebuild build \
  -project iosApp.xcodeproj \
  -scheme iosApp \
  -destination 'generic/platform=iOS Simulator'
```

## Adapter contract fixtures

The Swift test target validates the contracts used by raw callback wrappers,
KMP-NativeCoroutines async-sequence helpers, and Combine helpers without making
those libraries package dependencies. These adapters all enter the same
`KMPState.asyncSequence`, `callback`, or `publisher` paths.

When adding a version-specific integration job, pin its Kotlin and plugin
versions in a separate example project. Do not add those dependencies to the
core package.
