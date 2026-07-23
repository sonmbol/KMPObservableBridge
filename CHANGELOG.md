# Changelog

All notable changes follow Keep a Changelog and Semantic Versioning.

## [Unreleased]

### Added

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

### Removed

- Fixed two-, three-, and four-state overloads.
- Silent observation-error defaults.
