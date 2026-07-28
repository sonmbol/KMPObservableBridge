# Adoption Playbook

The objective is not a short-lived star count. It is a measurable path from a
repository visit to a correct integration that teams keep after evaluating it.

## First adopters

Offer hands-on help integrating one non-critical screen. Ask each team for:

- Kotlin, Coroutines, SKIE or KMP-NativeCoroutines, Swift, and Xcode versions
- The ViewModel ownership source
- One state stream and its lifecycle contract
- Permission before naming the application publicly

Suggested message:

> I maintain KMPObservableBridge, a dependency-light SwiftUI bridge for Kotlin
> state. I’m looking for two teams willing to try it on one screen. I’ll help
> with the integration and lifecycle review. In return, I’d value candid API
> feedback; public attribution is entirely optional.

Choose pilot screens that:

- Are non-critical and can be removed without a migration.
- Have one clearly owned ViewModel and one or two observable fields.
- Already use SKIE or KMP-NativeCoroutines successfully.
- Have tests or a deterministic interaction that exposes lifecycle mistakes.

For each pilot, record the time required to install, configure, render the first
value, and verify cancellation. Turn repeated confusion into documentation or a
compile-time diagnostic.

## Where to ask

- Kotlin Slack `#multiplatform`
- Swift Forums “Related Projects”
- Reddit `r/KotlinMultiplatform`
- Reddit `r/iOSProgramming`
- KMP community Discords and local mobile meetups
- Teams that have publicly described a KMP + SwiftUI architecture

Do not send bulk unsolicited messages. Contact maintainers only where they have
invited project discussion, and personalize the request around their published
integration.

## Production showcase

For every consenting adopter, record:

| Application | Integration | Minimum OS | Screens | Public link |
| --- | --- | --- | --- | --- |
| _Awaiting first adopter_ | — | — | — | — |

Never imply production use without confirmation from the application owner.

Before publishing a name, logo, quotation, benchmark, or architecture detail,
obtain explicit written permission for that specific material. An anonymous
technical case study is a valid alternative.

## Adoption funnel

Review monthly:

- Unique repository visitors and their referral sources
- Clones and package-resolution activity
- Unique cloners and dependent repositories
- Discussions that reach a working integration
- Evaluations that produce a rendered screen
- Evaluations that remain after one release cycle
- Time to first maintainer response

Stars are useful discovery signals, but successful integrations and retained
users are the primary measures.

## Evidence worth publishing

- A reproducible before/after adapter diff.
- Notification and body-evaluation counts for a real screen.
- Collector counts with parent, child, and environment wrappers.
- Cancellation behavior after navigation and model rebinding.
- Toolchain and framework versions for every benchmark.
- Limitations discovered during adoption and how they were resolved.

Never publish a synthetic benchmark as proof of application-level performance.
