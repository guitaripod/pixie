import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(String)
    case httpError(Int, String)
    case unauthorized
    case insufficientCredits
    case forbidden
    case tooManyRequests
    case noConnection
    case invalidResponse
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .httpError(let statusCode, let message):
            return "HTTP \(statusCode): \(message)"
        case .unauthorized:
            return "Authentication failed: Your API key may be invalid"
        case .insufficientCredits:
            return "Insufficient credits"
        case .forbidden:
            return "Access forbidden"
        case .tooManyRequests:
            return "Too many requests"
        case .noConnection:
            return "No internet connection"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}

protocol NetworkServiceProtocol {
    func get<T: Decodable>(_ endpoint: String, type: T.Type) async throws -> T
    func post<T: Decodable, U: Encodable>(_ endpoint: String, body: U, type: T.Type) async throws -> T
    func put<T: Decodable, U: Encodable>(_ endpoint: String, body: U, type: T.Type) async throws -> T
    func delete(_ endpoint: String) async throws
    func downloadData(from url: URL) async throws -> Data
}

class NetworkService: NetworkServiceProtocol {
    private let session: URLSession
    private let baseURL: String
    private var apiKey: String?
    init(baseURL: String = "https://openai-image-proxy.guitaripod.workers.dev") {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300
        configuration.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: configuration)
        self.baseURL = baseURL
    }
    func setAPIKey(_ key: String?) {
        self.apiKey = key
    }
    private func createRequest(for endpoint: String, method: String = "GET") throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw NetworkError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
    func get<T: Decodable>(_ endpoint: String, type: T.Type) async throws -> T {
        let request = try createRequest(for: endpoint, method: "GET")
        return try await performRequest(request, type: type)
    }
    func post<T: Decodable, U: Encodable>(_ endpoint: String, body: U, type: T.Type) async throws -> T {
        var request = try createRequest(for: endpoint, method: "POST")
        request.httpBody = try JSONEncoder().encode(body)
        return try await performRequest(request, type: type)
    }
    func put<T: Decodable, U: Encodable>(_ endpoint: String, body: U, type: T.Type) async throws -> T {
        var request = try createRequest(for: endpoint, method: "PUT")
        request.httpBody = try JSONEncoder().encode(body)
        return try await performRequest(request, type: type)
    }
    func delete(_ endpoint: String) async throws {
        let request = try createRequest(for: endpoint, method: "DELETE")
        _ = try await performRequest(request, type: EmptyResponse.self)
    }
    func downloadData(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.httpError(httpResponse.statusCode, "Failed to download image")
        }
        return data
    }
    private func performRequest<T: Decodable>(_ request: URLRequest, type: T.Type) async throws -> T {
        #if DEBUG
        logRequest(request)
        #endif
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }
        #if DEBUG
        logResponse(httpResponse, data: data)
        #endif
        if httpResponse.statusCode == 401 {
            throw NetworkError.unauthorized
        }
        if httpResponse.statusCode == 402 {
            throw NetworkError.insufficientCredits
        }
        if httpResponse.statusCode == 403 {
            throw NetworkError.forbidden
        }
        if httpResponse.statusCode == 429 {
            throw NetworkError.tooManyRequests
        }
        guard 200...299 ~= httpResponse.statusCode else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                if errorResponse.error.code == "insufficient_credits" {
                    throw NetworkError.insufficientCredits
                }
                throw NetworkError.serverError(errorResponse.error.message)
            }
            throw NetworkError.httpError(httpResponse.statusCode, HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
    #if DEBUG
    private func logRequest(_ request: URLRequest) {
        print("🌐 [\(request.httpMethod ?? "?")] \(request.url?.absoluteString ?? "Unknown URL")")
        if let headers = request.allHTTPHeaderFields {
            print("📋 Headers: \(headers)")
        }
        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            print("📦 Body: \(bodyString)")
        }
    }
    private func logResponse(_ response: HTTPURLResponse, data: Data) {
        print("✅ [\(response.statusCode)] \(response.url?.absoluteString ?? "Unknown URL")")
        if let responseString = String(data: data, encoding: .utf8) {
            let truncated = responseString.prefix(500)
            print("📄 Response: \(truncated)\(responseString.count > 500 ? "..." : "")")
        }
    }
    #endif
}

private struct EmptyResponse: Codable {}