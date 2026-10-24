import Foundation

/// Downloads the bytes of an image from an absolute URL, such as the `openai-image-proxy.guitaripod.workers.dev/r2/...` addresses mako returns for generated images. It uses the shared session with no headers, timeout or caching of its own, so a caller gets exactly what `URLSession.shared` gives.
nonisolated struct ImageDownloadClient: Sendable {
    static let shared = ImageDownloadClient()

    func data(from url: URL) async throws -> Data {
        try await URLSession.shared.data(from: url).0
    }

    func data(from url: URL, completion: @escaping @Sendable (Data?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, error in
            completion(error == nil ? data : nil)
        }.resume()
    }
}
