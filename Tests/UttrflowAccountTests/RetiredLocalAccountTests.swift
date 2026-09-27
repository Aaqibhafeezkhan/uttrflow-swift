import Foundation
import Testing

@testable import UttrflowAccount

/// ``RetiredLocalAccount``: an upgrade forgets the Mac-account record and nothing else.
@Suite("Forgetting the retired Mac account")
struct RetiredLocalAccountTests {
    @Test("forgetting removes the retired record and leaves the session where it is")
    func forgetsOnlyTheRetiredRecord() {
        let storage = MemoryStorage()
        storage.set(Data("{}".utf8), forKey: RetiredLocalAccount.key)
        storage.set(Data("profile".utf8), forKey: UserDefaultsProfileCache.defaultKey)

        RetiredLocalAccount.forget(in: storage)

        #expect(storage.data(forKey: RetiredLocalAccount.key) == nil)
        #expect(storage.data(forKey: UserDefaultsProfileCache.defaultKey) == Data("profile".utf8))
    }

    @Test("the key is the one the retired store wrote, so an upgrade finds it")
    func keyIsTheRetiredOne() {
        #expect(RetiredLocalAccount.key == "com.uttrflow.local-account.v1")
    }
}
