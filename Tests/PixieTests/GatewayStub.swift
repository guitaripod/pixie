import Foundation
import MidgarCommerce
import MidgarCore
import MidgarCredits
import os
@testable import Pixie

/// A Midgar ID that is always there, in the UUID form `appAccountToken` takes, with a fixed access token.
nonisolated struct StubIdentity: MidgarStoreIdentity, MidgarCreditsIdentity {
    static let midgarID = "9C4E1B2A-7D35-4F80-A1B6-3E5D7F9A0C24"
    static let accessToken = "stub-midgar-access-token"

    var midgarId: String {
        get async throws { Self.midgarID }
    }

    func accessToken() async throws -> String {
        Self.accessToken
    }

    func invalidateAccessToken() async {}
}

/// The Midgar gateway in these tests: no request reaches the network. It answers mako's balance, validate and legacy
/// identity routes and the ledger the store reports to, from a script the test sets, and records every request so the
/// test can read what the app sent. The state is one lock-guarded value, so it is shared by every request of the process
/// without any unsafe annotation; the suites that use it run serially.
nonisolated final class GatewayStub: URLProtocol {
    struct Request: Sendable {
        let method: String
        let path: String
        let headers: [String: String]
        let body: Data

        func header(_ name: String) -> String? {
            headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
        }

        func json() throws -> [String: String] {
            try JSONDecoder().decode([String: String].self, from: body)
        }
    }

    struct Answer: Sendable {
        let status: Int
        let body: String

        static func credited(added: Int, newBalance: Int) -> Answer {
            Answer(status: 200, body: #"{"success":true,"purchase_id":"p-1","credits_added":\#(added),"new_balance":\#(newBalance)}"#)
        }

        static func error(status: Int, code: String, message: String) -> Answer {
            Answer(status: status, body: #"{"error":{"code":"\#(code)","message":"\#(message)"}}"#)
        }
    }

    private struct State {
        var requests: [Request] = []
        var balance = 3
        var validate: [Answer] = []
        var legacyDelete = Answer(status: 200, body: "{}")
    }

    private static let host = "gateway.pixie-tests.invalid"
    private static let state = OSAllocatedUnfairLock(initialState: State())

    static let baseURL = URL(string: "https://\(host)")!

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GatewayStub.self]
        return URLSession(configuration: configuration)
    }

    static func httpConfiguration() -> MidgarHTTPConfiguration {
        MidgarHTTPConfiguration(baseURL: baseURL, appID: PixieMidgar.appID, session: session(), timeout: 5)
    }

    static func reset() {
        state.withLock { $0 = State() }
    }

    static func setBalance(_ balance: Int) {
        state.withLock { $0.balance = balance }
    }

    /// The answers to `POST .../credits/purchase/validate`, in order. The last one repeats for every later call.
    static func setValidate(_ answers: [Answer]) {
        state.withLock { $0.validate = answers }
    }

    static func setLegacyDelete(_ answer: Answer) {
        state.withLock { $0.legacyDelete = answer }
    }

    static var requests: [Request] {
        state.withLock { $0.requests }
    }

    static func requests(method: String, pathSuffix: String) -> [Request] {
        requests.filter { $0.method == method && $0.path.hasSuffix(pathSuffix) }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == host
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let recorded = Request(
            method: request.httpMethod ?? "GET",
            path: url.path,
            headers: request.allHTTPHeaderFields ?? [:],
            body: Self.body(of: request)
        )
        let answer = Self.answer(to: recorded)
        let response = HTTPURLResponse(url: url, statusCode: answer.status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(answer.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func answer(to request: Request) -> Answer {
        state.withLock { state in
            state.requests.append(request)
            switch (request.method, request.path) {
            case ("GET", let path) where path.hasSuffix("/v1/credits/balance"):
                return Answer(status: 200, body: #"{"balance":\#(state.balance),"currency":"credits"}"#)
            case ("POST", let path) where path.hasSuffix("/v1/credits/purchase/validate"):
                guard let first = state.validate.first else {
                    return Answer.error(status: 500, code: "unscripted", message: "no validate answer scripted")
                }
                if state.validate.count > 1 {
                    state.validate.removeFirst()
                }
                return first
            case ("DELETE", let path) where path.hasSuffix("/v1/identity"):
                return state.legacyDelete
            case ("POST", let path) where path.hasSuffix("/v1/ledger/transactions"):
                return Answer(status: 200, body: #"{"ok":true}"#)
            case ("GET", let path) where path.hasSuffix("/v1/ledger/entitlements"):
                let now = Int(Date().timeIntervalSince1970 * 1000)
                return Answer(status: 200, body: #"{"midgarId":"\#(StubIdentity.midgarID)","environment":"Sandbox","serverTime":\#(now),"entitlements":[]}"#)
            default:
                return Answer(status: 404, body: "{}")
            }
        }
    }

    /// An upload's body arrives as a stream, not as `httpBody`.
    private static func body(of request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return Data()
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 {
                break
            }
            data.append(buffer, count: count)
        }
        return data
    }
}
