/// Controls how frequently accepted state emissions invalidate SwiftUI.
public enum KMPUpdatePolicy: Sendable {
    /// Coalesces emissions queued in the same main-actor turn.
    case coalesced

    /// Delivers one invalidation for every accepted emission.
    case immediate
}
