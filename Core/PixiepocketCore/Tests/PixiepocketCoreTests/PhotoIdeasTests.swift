import Foundation
import PixiepocketCore
import Testing

struct PhotoIdeasTests {

    @Test func aGoodReplyGivesItsThreeIdeasAsTheyAre() {
        let reply = #"{"ideas":["Move the dog to a snowy forest","Paint it as a watercolour","Add a tiny party hat"]}"#
        #expect(PhotoIdeas.settle(reply: reply) == ["Move the dog to a snowy forest", "Paint it as a watercolour", "Add a tiny party hat"])
    }

    @Test func quotationMarksFullStopsAndLineBreaksAreTakenOff() {
        let reply = #"{"ideas":["\"Turn the sky\n to sunset.\"","「夜景に変える」。","  Add falling   snow  "]}"#
        #expect(PhotoIdeas.settle(reply: reply) == ["Turn the sky to sunset", "夜景に変える", "Add falling snow"])
    }

    @Test func emptyTooLongRepeatedAndLinkLikeIdeasAreLeftOut() {
        let long = String(repeating: "very ", count: 20) + "long idea"
        let reply = """
        {"ideas":["", "ok", "\(long)", "Add falling snow", "add falling snow", "Visit https://example.test now", "Mail me@example.test today", "Make it a painting"]}
        """
        #expect(PhotoIdeas.settle(reply: reply) == ["Add falling snow", "Make it a painting"])
    }

    @Test func noMoreThanThreeIdeasAreKept() {
        let reply = #"{"ideas":["Make it autumn","Make it winter","Make it spring","Make it summer"]}"#
        #expect(PhotoIdeas.settle(reply: reply) == ["Make it autumn", "Make it winter", "Make it spring"])
    }

    @Test func aReplyThatIsNotTheListGivesNothing() {
        #expect(PhotoIdeas.settle(reply: "three ideas: a, b, c").isEmpty)
        #expect(PhotoIdeas.settle(reply: #"{"ideas":"Make it autumn"}"#).isEmpty)
        #expect(PhotoIdeas.settle(reply: #"{"suggestions":["Make it autumn"]}"#).isEmpty)
    }

    @Test func theRequestCarriesTheAliasTheLanguageAndOnePictureAsADataURL() throws {
        let request = PhotoIdeasRequest(jpeg: Data([0xFF, 0xD8, 0xFF]), language: "Finnish", idempotencyKey: "key-1")
        let json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        #expect(json["alias"] as? String == "photo.ideas.v1")
        #expect(json["language"] as? String == "Finnish")
        #expect(json["idempotency_key"] as? String == "key-1")
        #expect(json["images"] as? [String] == ["data:image/jpeg;base64,/9j/"])
        #expect((json["input"] as? String)?.isEmpty == false)
        #expect(json.count == 5)
    }

    @Test func makosAnswerIsReadForItsContent() throws {
        let answer = #"{"alias":"photo.ideas.v1","content":"{\"ideas\":[\"Make it autumn\"]}","credits_charged":0,"model":"claude-haiku-5-5"}"#
        let reply = try JSONDecoder().decode(PhotoIdeasReply.self, from: Data(answer.utf8))
        #expect(PhotoIdeas.settle(reply: reply.content) == ["Make it autumn"])
    }
}
