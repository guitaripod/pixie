import Foundation
import PixiepocketCore
import Testing

struct WireModelTests {

    @Test func aGalleryImageDecodesFromMakosSnakeCaseFields() throws {
        let json = """
        {"id":"img_1","url":"https://example.test/r2/a.png","prompt":"a fox","created_at":"2026-10-01T10:00:00Z",
         "user_id":"u1","thumbnail_url":"https://example.test/r2/a-thumb.png","tags":["fox"],
         "metadata":{"width":1024,"height":1024,"format":"png","size_bytes":4096,"credits_used":21,
                     "quality":"low","model":"gemini-2.5-flash","revised_prompt":"a red fox"}}
        """
        let image = try JSONDecoder().decode(ImageMetadata.self, from: Data(json.utf8))

        #expect(image.id == "img_1")
        #expect(image.userId == "u1")
        #expect(image.thumbnailUrl == "https://example.test/r2/a-thumb.png")
        #expect(image.metadata?.creditsUsed == 21)
        #expect(image.metadata?.revisedPrompt == "a red fox")
        #expect(image.tags == ["fox"])
    }

    @Test func aGalleryPageKeepsItsPagingFields() throws {
        let json = #"{"images":[],"total":42,"page":3,"per_page":20}"#
        let page = try JSONDecoder().decode(GalleryResponse.self, from: Data(json.utf8))

        #expect(page.total == 42)
        #expect(page.page == 3)
        #expect(page.perPage == 20)
    }

    @Test func anInsufficientCreditsErrorCarriesWhatWasRequiredAndAvailable() throws {
        let json = #"{"error":{"message":"Not enough credits","code":"insufficient_credits","details":{"required_credits":50,"available_credits":12}}}"#
        let response = try JSONDecoder().decode(ErrorResponse.self, from: Data(json.utf8))

        #expect(response.error.code == "insufficient_credits")
        #expect(response.error.details?.requiredCredits == 50)
        #expect(response.error.details?.availableCredits == 12)
    }

    @Test func aCreditPackDecodesItsPriceAndBonus() throws {
        let json = #"{"id":"pack_s","name":"Small","credits":100,"price_usd_cents":499,"bonus_credits":10,"description":"100 credits"}"#
        let pack = try JSONDecoder().decode(CreditPack.self, from: Data(json.utf8))

        #expect(pack.priceUsdCents == 499)
        #expect(pack.bonusCredits == 10)
    }

    @Test func aGenerationRequestEncodesTheOpenAICompatibleKeys() throws {
        let request = ImageGenerationRequest(
            prompt: "a fox", model: "gemini-2.5-flash", n: 1, size: "1024x1024", quality: "low",
            background: nil, moderation: nil, outputCompression: 80, outputFormat: "png",
            partialImages: nil, stream: false, user: nil
        )
        let object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])

        #expect(object["output_compression"] as? Int == 80)
        #expect(object["output_format"] as? String == "png")
        #expect(object["outputCompression"] == nil)
    }

    @Test func aCreditEstimateRequestEncodesIsEditInSnakeCase() throws {
        let request = CreditEstimateRequest(prompt: nil, quality: "low", size: "1024x1024", n: 1, isEdit: true)
        let object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])

        #expect(object["is_edit"] as? Bool == true)
        #expect(object["isEdit"] == nil)
    }

    @Test func aPurchaseRequestEncodesItsPaymentFieldsInSnakeCase() throws {
        let request = PurchaseRequest(packId: "pack_s", paymentProvider: "revenuecat", paymentId: "tx1", paymentCurrency: "USD")
        let object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])

        #expect(object["pack_id"] as? String == "pack_s")
        #expect(object["payment_provider"] as? String == "revenuecat")
        #expect(object["payment_id"] as? String == "tx1")
        #expect(object["payment_currency"] as? String == "USD")
    }

    @Test func usageTotalsDecodeAsSixtyFourBitCounters() throws {
        let json = #"{"user_id":"u1","total_requests":5000000000,"total_tokens":1,"total_images":2,"period_start":"a","period_end":"b"}"#
        let usage = try JSONDecoder().decode(UsageResponse.self, from: Data(json.utf8))

        #expect(usage.totalRequests == 5_000_000_000)
    }
}

struct EditModelTests {
    private static let summaryJSON = """
    {"balance":100,"currency":"credits","edits":{"credits_per_edit":21,"balance_edits":4,
     "tiers":[{"tier":"standard","edits":1},{"tier":"max","edits":5}],
     "runway":{"state":"active","days":7,"daily_limit":5,"today_remaining":3,"resets_at":"2026-11-03T00:00:00Z",
               "ends_at":"2026-11-09T10:00:00+00:00"}}}
    """

    private func summary(premium: Allowance? = nil, runway: Runway? = nil, balanceEdits: Int = 4) -> EditsSummary {
        EditsSummary(
            creditsPerEdit: 21,
            balanceEdits: balanceEdits,
            tiers: [TierCost(tier: "standard", edits: 1), TierCost(tier: "max", edits: 5)],
            premium: premium,
            runway: runway
        )
    }

    private func runway(_ state: Runway.State, today: Int) -> Runway {
        Runway(state: state, days: 7, dailyLimit: 5, todayRemaining: today, resetsAt: "2026-11-03T00:00:00Z", endsAt: nil)
    }

    @Test func aBalanceFromAServerThatSellsEditsCarriesItsSummary() throws {
        let balance = try JSONDecoder().decode(CreditBalance.self, from: Data(Self.summaryJSON.utf8))

        #expect(balance.balance == 100)
        #expect(balance.edits?.balanceEdits == 4)
        #expect(balance.edits?.edits(forTier: "max") == 5)
        #expect(balance.edits?.runway?.state == .active)
        #expect(balance.edits?.runway?.todayRemaining == 3)
        #expect(balance.edits?.premium == nil)
    }

    @Test func aBalanceFromAnOlderServerHasNoSummary() throws {
        let balance = try JSONDecoder().decode(CreditBalance.self, from: Data(#"{"balance":65,"currency":"credits"}"#.utf8))

        #expect(balance.balance == 65)
        #expect(balance.edits == nil)
    }

    @Test func plusPaysFirstAndFallsBackToTheBalanceWhenTheWeekIsUsedUp() {
        let plus = summary(premium: Allowance(limit: 60, remaining: 7, resetsAt: "2026-11-09T00:00:00Z"))

        #expect(plus.funding(forTier: "standard") == .plus(remaining: 7))
        #expect(plus.funding(forTier: "max") == .plus(remaining: 7))
        #expect(plus.funding(forTier: "max", images: 2) == .balance(edits: 10, affordable: false))
    }

    @Test func thePixieWeekCoversStandardEditsOnlyWhileTodayHasSome() {
        #expect(summary(runway: runway(.available, today: 5)).funding(forTier: "standard") == .runway(remaining: 5))
        #expect(summary(runway: runway(.active, today: 1)).funding(forTier: "standard") == .runway(remaining: 1))
        #expect(summary(runway: runway(.active, today: 0)).funding(forTier: "standard") == .balance(edits: 1, affordable: true))
        #expect(summary(runway: runway(.active, today: 5)).funding(forTier: "max") == .balance(edits: 5, affordable: false))
        #expect(summary(runway: runway(.ended, today: 0)).funding(forTier: "standard") == .balance(edits: 1, affordable: true))
        #expect(summary(runway: runway(.active, today: 3)).funding(forTier: "standard", images: 4) == .balance(edits: 4, affordable: true))
    }

    @Test func theWeekCountsWholeDaysLeftAndHasNoneBeforeItStarts() throws {
        let balance = try JSONDecoder().decode(CreditBalance.self, from: Data(Self.summaryJSON.utf8))
        let runway = try #require(balance.edits?.runway)
        let now = try #require(ISO8601DateFormatter().date(from: "2026-11-04T09:00:00Z"))

        #expect(runway.daysLeft(at: now) == 6)
        #expect(runway.daysLeft(at: try #require(ISO8601DateFormatter().date(from: "2026-11-09T11:00:00Z"))) == 0)
        #expect(self.runway(.available, today: 5).daysLeft() == nil)
    }
}
