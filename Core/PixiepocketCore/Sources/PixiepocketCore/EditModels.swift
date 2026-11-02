import Foundation

/// The edits part of mako's balance response (mako migration 035): what one edit costs in credits, the balance in
/// edits, what each tier costs, and the Plus allowance or the Pixie Week, whichever applies to the person.
public struct EditsSummary: Codable, Sendable, Equatable {
    public let creditsPerEdit: Int
    public let balanceEdits: Int
    public let tiers: [TierCost]
    public let premium: Allowance?
    public let runway: Runway?

    public init(creditsPerEdit: Int, balanceEdits: Int, tiers: [TierCost], premium: Allowance?, runway: Runway?) {
        self.creditsPerEdit = creditsPerEdit
        self.balanceEdits = balanceEdits
        self.tiers = tiers
        self.premium = premium
        self.runway = runway
    }

    enum CodingKeys: String, CodingKey {
        case tiers, premium, runway
        case creditsPerEdit = "credits_per_edit"
        case balanceEdits = "balance_edits"
    }

    /// What one image on `tier` costs in edits; a tier the server did not list costs one.
    public func edits(forTier tier: String) -> Int {
        tiers.first { $0.tier == tier }?.edits ?? 1
    }

    /// How a request of `images` images on `tier` would be paid, mirroring mako's order: the Plus allowance, then for
    /// a standard edit the Pixie Week's edits for today, then the balance.
    public func funding(forTier tier: String, images: Int = 1) -> EditFunding {
        let cost = edits(forTier: tier) * max(images, 1)
        if let premium {
            if premium.remaining >= cost { return .plus(remaining: premium.remaining) }
        } else if tier == EditTier.standard, let runway, runway.isOpen, runway.todayRemaining >= cost {
            return .runway(remaining: runway.todayRemaining)
        }
        return .balance(edits: cost, affordable: balanceEdits >= cost)
    }
}

/// The tier names mako prices.
public enum EditTier {
    public static let standard = "standard"
    public static let max = "max"
}

public struct TierCost: Codable, Sendable, Equatable {
    public let tier: String
    public let edits: Int

    public init(tier: String, edits: Int) {
        self.tier = tier
        self.edits = edits
    }
}

/// A Plus subscriber's edits for the current week.
public struct Allowance: Codable, Sendable, Equatable {
    public let limit: Int
    public let remaining: Int
    public let resetsAt: String

    public init(limit: Int, remaining: Int, resetsAt: String) {
        self.limit = limit
        self.remaining = remaining
        self.resetsAt = resetsAt
    }

    enum CodingKeys: String, CodingKey {
        case limit, remaining
        case resetsAt = "resets_at"
    }
}

/// The Pixie Week: free standard edits each day for the first days after a person's first edit.
public struct Runway: Codable, Sendable, Equatable {
    public enum State: String, Codable, Sendable {
        case available
        case active
        case ended
    }

    public let state: State
    public let days: Int
    public let dailyLimit: Int
    public let todayRemaining: Int
    public let resetsAt: String
    public let endsAt: String?

    public init(state: State, days: Int, dailyLimit: Int, todayRemaining: Int, resetsAt: String, endsAt: String?) {
        self.state = state
        self.days = days
        self.dailyLimit = dailyLimit
        self.todayRemaining = todayRemaining
        self.resetsAt = resetsAt
        self.endsAt = endsAt
    }

    enum CodingKeys: String, CodingKey {
        case state, days
        case dailyLimit = "daily_limit"
        case todayRemaining = "today_remaining"
        case resetsAt = "resets_at"
        case endsAt = "ends_at"
    }

    /// True before the first edit and during the week: a standard edit can still be free.
    public var isOpen: Bool {
        state != .ended
    }

    /// When the week ends, once it has started.
    public var endDate: Date? {
        endsAt.flatMap(Self.parse)
    }

    /// Whole days left in the week at `now`, counting the current one; nil before it starts.
    public func daysLeft(at now: Date = Date()) -> Int? {
        guard let endDate else { return nil }
        let seconds = endDate.timeIntervalSince(now)
        return seconds <= 0 ? 0 : Int((seconds / 86_400).rounded(.up))
    }

    private static func parse(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return ISO8601DateFormatter().date(from: value) ?? fractional.date(from: value)
    }
}

/// How the next edit would be paid.
public enum EditFunding: Sendable, Equatable {
    /// Free under Plus, with this many edits left this week.
    case plus(remaining: Int)
    /// Free in the Pixie Week, with this many free edits left today.
    case runway(remaining: Int)
    /// Paid from the balance: this many edits, and whether the balance covers them.
    case balance(edits: Int, affordable: Bool)

    public var isFree: Bool {
        if case .balance = self { return false }
        return true
    }
}
