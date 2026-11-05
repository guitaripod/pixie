import Foundation
import PixiepocketCore
import Testing

@testable import Pixie

@MainActor
struct EditPriceTests {
    private func balance(credits: Int, runway: Runway? = nil, premium: Allowance? = nil) -> CreditBalance {
        let summary = EditsSummary(
            creditsPerEdit: 21,
            balanceEdits: credits / 21,
            tiers: [TierCost(tier: "standard", edits: 1), TierCost(tier: "max", edits: 5)],
            premium: premium,
            runway: runway
        )
        return CreditBalance(balance: credits, currency: "credits", edits: summary)
    }

    private func runway(_ state: Runway.State, today: Int, endsAt: String? = nil) -> Runway {
        Runway(state: state, days: 7, dailyLimit: 5, todayRemaining: today, resetsAt: "2026-11-03T00:00:00Z", endsAt: endsAt)
    }

    @Test func aBalanceReadsInWholeEditsFromItsLiveCredits() {
        #expect(EditPrice.edits(of: balance(credits: 65)) == 3)
        #expect(EditPrice.edits(of: CreditBalance(balance: 65, currency: "credits")) == 3)
        #expect(EditPrice.edits(of: CreditBalance(balance: -4, currency: "credits")) == 0)
        #expect(EditPrice.edits(inCredits: 840, balance: nil) == 40)
    }

    @Test func maxCostsFiveEditsAndTheBalanceDecidesOnceNoAllowanceCovers() {
        #expect(EditPrice.funding(tier: .max, balance: balance(credits: 100)) == .balance(edits: 5, affordable: false))
        #expect(EditPrice.funding(tier: .max, balance: balance(credits: 105)) == .balance(edits: 5, affordable: true))
        #expect(EditPrice.funding(tier: .standard, balance: nil) == nil)
    }

    @Test func thePixieWeekAndPlusMakeAnEditFree() {
        #expect(EditPrice.funding(tier: .standard, balance: balance(credits: 0, runway: runway(.active, today: 2))) == .runway(remaining: 2))
        let plus = Allowance(limit: 60, remaining: 59, resetsAt: "2026-11-09T00:00:00Z")
        #expect(EditPrice.funding(tier: .max, balance: balance(credits: 0, premium: plus)) == .plus(remaining: 59))
    }

    @Test func aModelIdAnOlderVersionSavedReadsAsStandard() {
        #expect(ImageModel(storedValue: "gemini-2.5-flash") == .standard)
        #expect(ImageModel(storedValue: "max") == .max)
        #expect(ImageModel.displayName(forRecorded: "gpt-image-2.5-sunburst") == "GPT Image 2.5")
        #expect(ImageModel.displayName(forRecorded: "gpt-image-2.6-sunburst") == "GPT Image 2.6")
        #expect(ImageModel.displayName(forRecorded: "gemini-nano-banana-2.1") == "Nano Banana 2.1")
    }

    @Test func theWeekIsAnnouncedOnceAndItsEndOnlyToWhoeverWasTold() {
        let defaults = UserDefaults(suiteName: "EditPriceTests-\(UUID().uuidString)")!
        let week = PixieWeek(defaults: defaults)

        #expect(week.moment(for: runway(.available, today: 5)) == nil)
        #expect(week.moment(for: runway(.ended, today: 0)) == nil)
        guard case .started(5, 7, _) = week.moment(for: runway(.active, today: 4, endsAt: "2026-11-09T10:00:00Z")) else {
            Issue.record("the running week is announced")
            return
        }
        defaults.set(true, forKey: "pixieWeek.announced")
        #expect(week.moment(for: runway(.active, today: 3)) == nil)
        #expect(week.moment(for: runway(.ended, today: 0)) == .ended)
        defaults.set(true, forKey: "pixieWeek.endNoted")
        #expect(week.moment(for: runway(.ended, today: 0)) == nil)
    }

    @Test func theReminderFiresTwoDaysBeforeTheEndAndNeverInThePast() throws {
        let end = try #require(ISO8601DateFormatter().date(from: "2026-11-09T10:00:00Z"))
        let now = try #require(ISO8601DateFormatter().date(from: "2026-11-02T10:00:00Z"))
        #expect(PixieWeek.reminderDate(endsAt: end, now: now) == end.addingTimeInterval(-2 * 86_400))
        #expect(PixieWeek.reminderDate(endsAt: end, now: end.addingTimeInterval(-86_400)) == nil)
    }
}
