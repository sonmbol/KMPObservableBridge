# Contributing

Thank you for helping make Kotlin state feel native in SwiftUI. Bug reports,
API critiques, documentation fixes, integration fixtures, and performance
evidence are all useful.

## Before changing code

1. Search the [issues](https://github.com/sonmbol/KMPObservableBridge/issues)
   and [discussions](https://github.com/sonmbol/KMPObservableBridge/discussions).
2. Open an issue before changing public API or observable behavior.
3. Keep `KMPObservableBridge` independent of Kotlin frameworks and third-party
   runtimes. Exporter-specific behavior belongs in its integration target.
4. Preserve existing consumer source compatibility unless the issue explicitly
   targets a major release.

Good first contributions include clearer diagnostics, DocC examples, example
accessibility, and additional integration fixtures. Changes to invalidation,
ownership, cancellation, macros, or actor isolation require focused tests.

## Validation

Run:

```shell
swift test -Xswiftc -strict-concurrency=complete -Xswiftc -warnings-as-errors
./Scripts/check-api.sh
./Scripts/check-package-manifests.sh
git diff --check
```

When changing the example integration, also build DailyPulse using the procedure
in [`Examples/DailyPulse/iosApp/README.md`](Examples/DailyPulse/iosApp/README.md).

## Pull requests

- Keep the change focused and explain its rendering and lifetime effects.
- Add regression tests for lifecycle, actor isolation, cancellation, rebinding,
  dependency selection, and deallocation where applicable.
- Document public APIs and include migration notes for behavior changes.
- Include toolchain, configuration, commands, and raw measurements with every
  performance claim.
- Never include private application code, credentials, or adopter information
  without permission.

All participation is governed by the
[`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).
