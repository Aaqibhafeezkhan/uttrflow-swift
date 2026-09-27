// This Mac's name, as System Settings shows it under Sharing.

import SystemConfiguration

/// The Mac's computer name, read once from the local configuration store without touching the network.
enum MacName {
    /// The name, or `nil` when the store will not say.
    static let current: String? = SCDynamicStoreCopyComputerName(nil, nil) as String?
}
