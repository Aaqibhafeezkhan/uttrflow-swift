// A session held in memory, so an app under test starts signed in or signed out without a key or a disk.

import Foundation
import Synchronization
import UttrflowAccount
import UttrflowCore

@testable import Uttrflow

/// A profile cache holding one session until it is cleared; it verifies nothing, which the gate never asks it to.
final class HeldSession: ProfileCache {
    private let held: Mutex<Profile?>

    /// Starts signed in or signed out.
    init(signedIn: Bool) {
        held = Mutex(signedIn ? Self.profile : nil)
    }

    func load() -> Profile? { held.withLock { $0 } }

    func save(_ profile: Profile) throws(AccountError) { held.withLock { $0 = profile } }

    func clear() { held.withLock { $0 = nil } }

    /// The account layer over this session and the in-memory backend, which reaches no network.
    var layer: OnboardingAccountLayer {
        OnboardingAccountLayer(authentication: InMemoryAuthenticationService(), profiles: self)
    }

    /// A current session for an invented person.
    static let profile: Profile = {
        let account = Account(
            identifier: "held-1", displayName: "Held Session", emailAddress: "held@example.com",
            provider: .google)
        let entitlement = Entitlement(
            account: account, plan: .pro, expiresAt: .distantFuture, signature: "held")
        return Profile(
            account: account,
            subscription: Profile.Subscription(
                plan: .pro, status: .active, currentPeriodEnd: nil, effectivePlan: .pro,
                limits: Profile.Limits(monthlyMinutes: nil, customDictionaryEntries: nil)),
            devices: [], entitlement: entitlement, fetchedAt: .distantPast)
    }()
}
