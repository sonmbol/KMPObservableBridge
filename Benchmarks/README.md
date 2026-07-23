# Benchmarks

Run the package performance suite on an otherwise idle machine:

```shell
swift test --filter KMPObservableBridgePerformanceTests
```

The suite measures 10,000 immediate emissions and 1,000 store
creation/teardown cycles. Record hardware, OS, Swift version, build
configuration, mean, and standard deviation when publishing results.

Competitor comparisons must use the same generated Kotlin fixture, state shape,
emission count, device, and optimized build. Do not compare package debug
results with another library's release results.
