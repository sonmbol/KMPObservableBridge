# Contributing

1. Open an issue for public API or behavior changes.
2. Keep the core free of Kotlin framework and third-party dependencies.
3. Add tests for lifecycle, actor isolation, cancellation, and deallocation.
4. Run:

```shell
swift test
swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
git diff --check
```

Public APIs must include documentation and migration notes. Performance claims
must include a reproducible benchmark.
