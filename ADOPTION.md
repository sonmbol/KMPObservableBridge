# Adoption Playbook

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

## Success measures

Review monthly:

- README visits to package-resolution or clone activity
- Swift Package Index builds
- Unique cloners and dependent repositories
- Discussions that reach a working integration
- Time to first maintainer response
- Retention of known adopters after one release cycle

Stars are useful discovery signals, but successful integrations and retained
users are the primary measures.
