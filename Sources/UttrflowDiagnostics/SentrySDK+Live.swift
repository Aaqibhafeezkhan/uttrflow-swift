// The real crash reporter behind CrashReportingSDK.
public import Sentry

/// Starts and closes the Sentry SDK in this process.
public struct LiveCrashReportingSDK: CrashReportingSDK {
    /// Nothing to hold; the SDK is process-wide.
    public init() {}

    /// Starts the SDK with the options `configure` fills in.
    public func start(_ configure: @escaping @Sendable (Options) -> Void) {
        SentrySDK.start(configureOptions: configure)
    }

    /// Closes the SDK and its crash handler.
    public func close() {
        SentrySDK.close()
    }
}
