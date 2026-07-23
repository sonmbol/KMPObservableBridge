# Benchmark Results

These numbers are reference measurements, not universal performance claims.
Run the committed XCTest performance suite on your target hardware before
making capacity decisions.

## 2026-07-23 reference run

| Environment | Value |
| --- | --- |
| Hardware | MacBook Pro, Apple M3 Pro, 18 GB |
| OS | macOS 26.4.1 |
| Swift | Apple Swift 6.2 |
| Configuration | SwiftPM release |
| Command | `swift test -c release --filter KMPObservableBridgePerformanceTests` |

| Scenario | Work per measured iteration | Mean | Relative standard deviation |
| --- | ---: | ---: | ---: |
| Immediate emissions | 10,000 publisher emissions | 0.007 s | 18.198% |
| Store lifecycle | 1,000 creation/teardown cycles | 0.004 s | 14.365% |

The full XCTest run completed two performance tests with zero failures.
Variance includes local machine scheduling and should be reduced with dedicated
CI hardware before establishing regression thresholds.

## Cross-library comparison

KMP-ObservableViewModel and manual-adapter cells intentionally remain
unpublished until equivalent optimized harnesses use the same generated Kotlin
model, state shape, emission schedule, hardware, and instrumentation. This
repository does not claim superiority from incomparable measurements.
