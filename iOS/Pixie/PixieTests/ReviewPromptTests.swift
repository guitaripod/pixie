import Foundation
import MidgarCommerce
import Testing

@testable import Pixie

struct ReviewPromptTests {
    private final class Storage: MidgarReviewStorage, @unchecked Sendable {
        var state = MidgarReviewState()
        func load() -> MidgarReviewState { state }
        func save(_ state: MidgarReviewState) -> Bool {
            self.state = state
            return true
        }
    }

    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "ReviewPromptTests-\(UUID().uuidString)")!
        return defaults
    }

    @Test func theNewestRecordedAskBecomesThePoliciesLastPrompt() {
        let defaults = makeDefaults()
        let older = Date(timeIntervalSince1970: 1_700_000_000)
        let newer = Date(timeIntervalSince1970: 1_750_000_000)
        defaults.set([older.timeIntervalSince1970, newer.timeIntervalSince1970], forKey: LegacyReviewState.askDatesKey)
        let storage = Storage()

        LegacyReviewState.migrate(from: defaults, into: storage)

        #expect(storage.state.lastPrompt == newer)
    }

    @Test func theOldPerVersionFlagCountsAsAnAskMadeNow() {
        let defaults = makeDefaults()
        defaults.set("1.5.0", forKey: LegacyReviewState.legacyPromptedVersionKey)
        let storage = Storage()
        let now = Date(timeIntervalSince1970: 1_760_000_000)

        LegacyReviewState.migrate(from: defaults, into: storage, now: now)

        #expect(storage.state.lastPrompt == now)
        #expect(storage.state.lastPromptedVersion == "1.5.0")
    }

    @Test func aPersonNeverAskedKeepsAnEmptyHistory() {
        let storage = Storage()

        LegacyReviewState.migrate(from: makeDefaults(), into: storage)

        #expect(storage.state.lastPrompt == nil)
    }

    @Test func theMigrationRunsOnce() {
        let defaults = makeDefaults()
        defaults.set([1_700_000_000.0], forKey: LegacyReviewState.askDatesKey)
        let storage = Storage()
        LegacyReviewState.migrate(from: defaults, into: storage)
        storage.state.lastPrompt = nil

        LegacyReviewState.migrate(from: defaults, into: storage)

        #expect(storage.state.lastPrompt == nil)
    }

    @Test func aPolicyThatWasPromptedRecentlyHoldsBack() {
        let storage = Storage()
        storage.state = MidgarReviewState(firstLaunch: .distantPast, sessions: 50, lastPrompt: Date())
        let policy = MidgarReviewPolicy(storage: storage, appVersion: "9.9.9")

        #expect(policy.noteSuccess() == false)
        #expect(policy.evaluate() == .hold(.promptedRecently))
    }
}
