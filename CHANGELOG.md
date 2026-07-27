# Changelog

All notable changes follow Keep a Changelog and Semantic Versioning.

## [Unreleased]

## [1.1.0] - 2026-07-27

### Added

- Generated static observation plans with compiler-checked ViewModel and
  `StateFlow` key paths.
- One weakly registered shared collection hub per model identity.
- Whole-state duplicate suppression and optional projection filtering.
- Arbitrary heterogeneous state key paths using Swift parameter packs.
- `KMPViewModelStore` projected values and environment injection.
- Direct and optional flow-backed child ViewModel wrappers.
- Automatic `KMPDisposable` lifecycle integration.
- Coalesced and immediate update policies.
- Observation-framework delivery with legacy `ObservableObject` fallback.
- Structured observation failure policies and system logging.
- Strict-concurrency, lifecycle, child, performance, and memory tests.

### Changed

- Advanced mixed sources use the `adapters:` label.
- Observation error closures are represented by
  `KMPObservationFailurePolicy`.
- Coalescing is the default update behavior.
- Zero-configuration wrappers now require `KMPStaticallyObservable`
  conformance, making missing generation a compile-time error.
- Static `KMPStateObject` factories remain lazy until SwiftUI realizes their
  identity storage.
- Rebinding now honors the configured coalescing policy.
- Shared hubs use allocation-light integer listener IDs, support reentrant
  teardown, and deregister from the weak registry in constant time.
- The minimum iOS deployment target is now iOS 15.

### Removed

- Fixed two-, three-, and four-state overloads.
- Silent observation-error defaults.
- Runtime SKIE getter discovery, Objective-C interception, selector lookup, and
  undocumented iterator ABI invocation.
