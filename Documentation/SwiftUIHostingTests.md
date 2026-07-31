# SwiftUI hosting smoke tests

`KMPObservableBridgeSwiftUIHostingTests` mounts two independent projected
fields in real `UIHostingController` or `NSHostingController` view graphs. The
suite records each subtree's body evaluation and keeps the two fields in
separate `View` identities.

The smoke tests cover:

- field B invalidation without reevaluating the field A-only subtree on iOS
  17+ and macOS 14+;
- global invalidation of both projected-field subtrees;
- the production `ObservableObject` fallback forced on a current runtime;
- the real runtime fallback when the same test bundle runs on iOS 15 or iOS
  16; and
- one shared observation setup across the two identities plus deterministic
  cancellation after the hosted content is removed.

The tests use positive render and cancellation signals. Timeouts are failure
bounds only; the suite does not use inverted expectations or sleeps to infer
that an unrelated body was not evaluated.

## Toolchain and destinations

The package supports Xcode 15 or newer because its baseline manifest requires
Swift 5.9. The hosting suite is currently verified with Xcode 26.5.

Run the macOS host through the package's required validation command:

```sh
swift test \
  --filter KMPObservableBridgeSwiftUIHostingTests \
  -Xswiftc -strict-concurrency=complete \
  -Xswiftc -warnings-as-errors
```

For an iOS simulator, open `Package.swift` in the supported Xcode version,
select the `KMPObservableBridge-Package` scheme, choose an iOS simulator, and
run `KMPObservableBridgeSwiftUIHostingTests`.

- Use an iOS 17 or newer destination for the field-level Observation path.
- Use an iOS 15 or iOS 16 destination for the real runtime fallback contract.

The forced-fallback test runs on current macOS and iOS runtimes, so the
fallback rendering contract remains covered even when an iOS 15/16 runtime is
not installed. The real-runtime fallback test reports an explicit skip on
Observation-capable destinations.
