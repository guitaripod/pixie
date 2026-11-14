import Foundation

/// What is sent to have edits suggested for one photo: the alias, a line of text for the model, the language the
/// ideas are wanted in, a small copy of the photo and a key that keeps a repeat from being charged twice.
public struct PhotoIdeasRequest: Encodable, Sendable, Equatable {
    public let alias: String
    public let input: String
    public let language: String
    public let images: [String]
    public let idempotencyKey: String

    /// - Parameters:
    ///   - jpeg: The copy of the photo to send, already downsized to `PhotoIdeas.sentPixels` on its longest side.
    ///   - language: The English name of the language the ideas are wanted in.
    public init(jpeg: Data, language: String, idempotencyKey: String) {
        alias = PhotoIdeas.alias
        input = PhotoIdeas.input
        self.language = language
        images = ["data:image/jpeg;base64," + jpeg.base64EncodedString()]
        self.idempotencyKey = idempotencyKey
    }

    enum CodingKeys: String, CodingKey {
        case alias, input, language, images
        case idempotencyKey = "idempotency_key"
    }
}

/// mako's answer to an alias call, of which only the reply text is read here: a JSON string.
public struct PhotoIdeasReply: Decodable, Sendable, Equatable {
    public let content: String
}

/// Edits suggested for the photo a person picked. The model looks at a small copy of the photo and answers three
/// short instructions; what it wrote is checked here before any of it becomes a chip a person can tap.
public enum PhotoIdeas {
    public static let alias = "photo.ideas.v1"
    static let input = "Suggest three edits for this photo."
    public static let count = 3
    /// The longest side, in pixels, of the copy of the photo that is sent. Enough to see what the photo shows,
    /// and a fraction of what an edit itself uploads.
    public static let sentPixels = 512
    public static let longestIdea = 64
    static let fewestCharacters = 6

    /// The ideas of a reply that are fit to show: one line each, without the quotation marks or the full stop a
    /// model adds, not empty, not too long, never a link or an address, no idea twice, and three at most.
    public static func settle(reply content: String) -> [String] {
        struct Listing: Decodable {
            let ideas: [String]
        }
        guard let listing = try? JSONDecoder().decode(Listing.self, from: Data(content.utf8)) else { return [] }
        var seen: Set<String> = []
        var kept: [String] = []
        for raw in listing.ideas {
            let idea = tidied(raw)
            guard (fewestCharacters...longestIdea).contains(idea.count), !looksLikeALink(idea) else { continue }
            guard seen.insert(idea.lowercased()).inserted else { continue }
            kept.append(idea)
            if kept.count == count { break }
        }
        return kept
    }

    private static let wrapping = CharacterSet(charactersIn: "\"'“”‘’«»「」『』 .。")

    private static func tidied(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ").trimmingCharacters(in: wrapping)
    }

    private static func looksLikeALink(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("http") || lower.contains("www.") || lower.contains("@") || lower.contains("://")
    }
}
