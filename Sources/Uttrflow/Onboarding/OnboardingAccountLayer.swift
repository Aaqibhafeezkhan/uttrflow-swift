// The backend and profile cache, paired.

import Foundation
import UttrflowAccount
import UttrflowUX

/// The backend and the cache that believes what it signs, paired so the two cannot disagree about the key.
struct OnboardingAccountLayer {
    let authentication: any AuthenticationService
    let profiles: any ProfileCache
    /// Where usage reports go; a recording sender, so a development build sends nothing anywhere.
    var telemetry: any TelemetrySending = RecordingTelemetrySender()

    /// Re-reads the profile from the server and caches whatever comes back.
    var refresh: AccountRefresh {
        AccountRefresh(service: authentication, profiles: profiles)
    }

    /// The Info.plist key naming the backend; absent in a development build.
    static let endpointKey = "UttrflowBackendURL"

    /// The real backend only when both its address and its public key are present; otherwise development.
    static func forThisBuild(bundle: Bundle = .main) -> OnboardingAccountLayer {
        let configured = (bundle.object(forInfoDictionaryKey: endpointKey) as? String)
            .flatMap(URL.init(string:))
        guard let configured, Ed25519EntitlementVerifier.release.isConfigured else {
            return development()
        }
        return production(baseURL: configured)
    }

    /// The real thing: a URL session, the Keychain, and this Mac's own identity.
    static func production(baseURL: URL) -> OnboardingAccountLayer {
        let transport = URLSessionTransport()
        let authentication = HTTPAuthenticationService(
            baseURL: baseURL,
            transport: transport,
            tokens: KeychainTokenStore(),
            device: MacDeviceIdentity.system())
        return OnboardingAccountLayer(
            authentication: authentication,
            profiles: UserDefaultsProfileCache(),
            telemetry: HTTPTelemetrySender(
                baseURL: baseURL, transport: transport,
                bearer: { await authentication.accessTokenIfSignedIn() }))
    }

    /// The in-memory service with a per-process Ed25519 key, so the signature check runs in development too.
    static func development() -> OnboardingAccountLayer {
        let service = InMemoryAuthenticationService()
        return OnboardingAccountLayer(
            authentication: service,
            profiles: UserDefaultsProfileCache(verifier: service.verifier))
    }
}
