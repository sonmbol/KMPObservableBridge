public extension KMPState {
    /// Observes a callback-style KMP API.
    ///
    /// Adapters receiving callbacks on worker threads must cross to the main
    /// actor before invoking `notify` or `reportError`.
    static func callback(
        _ observe: @escaping @MainActor (
            ViewModel,
            @escaping Notify,
            @escaping ReportError
        ) -> KMPObservation
    ) -> Self {
        Self(observe: observe)
    }

    /// Builds a custom observation for advanced interoperability adapters.
    static func custom(
        _ observe: @escaping @MainActor (
            ViewModel,
            @escaping Notify,
            @escaping ReportError
        ) -> KMPObservation
    ) -> Self {
        Self(observe: observe)
    }
}
