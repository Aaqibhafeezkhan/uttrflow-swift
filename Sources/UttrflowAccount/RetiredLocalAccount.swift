// The retired Mac-account record, kept only so an upgrade can remove it.

/// Where a build that offered working without an account kept that choice; nothing reads it now.
public enum RetiredLocalAccount {
    /// The defaults key the retired record lived under.
    public static let key = "com.uttrflow.local-account.v1"

    /// Removes the retired record, so an upgraded Mac holds no account that is not a session.
    public static func forget(in storage: any SessionStorage = SystemDefaultsStorage()) {
        storage.set(nil, forKey: key)
    }
}
