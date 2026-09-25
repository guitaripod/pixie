import Foundation

final class LogFileWriter: @unchecked Sendable {
    static let shared = LogFileWriter(maxBytes: 2 * 1024 * 1024)

    private let queue = DispatchQueue(label: "pixie.LogFileWriter", qos: .utility)
    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private let pid = ProcessInfo.processInfo.processIdentifier
    private let maxBytes: UInt64
    let currentURL: URL
    let previousURL: URL
    private var handle: FileHandle?

    init(maxBytes: UInt64) {
        self.maxBytes = maxBytes
        let libDir = (try? FileManager.default.url(
            for: .libraryDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        let logsDir = libDir.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        self.currentURL = logsDir.appendingPathComponent("pixie.log")
        self.previousURL = logsDir.appendingPathComponent("pixie.previous.log")
    }

    func append(level: String, category: String, message: String) {
        let stamp = dateFormatter.string(from: Date())
        let lvl = level.padding(toLength: 5, withPad: " ", startingAt: 0)
        let cat = category.padding(toLength: 12, withPad: " ", startingAt: 0)
        let line = "\(stamp) [\(pid)] [\(lvl)] [\(cat)] \(message)\n"
        queue.async { [weak self] in self?.write(line) }
    }

    func snapshot() -> URL? {
        FileManager.default.fileExists(atPath: currentURL.path) ? currentURL : nil
    }

    func clear() {
        queue.async { [weak self] in
            guard let self else { return }
            try? self.handle?.close()
            self.handle = nil
            try? FileManager.default.removeItem(at: self.currentURL)
            try? FileManager.default.removeItem(at: self.previousURL)
        }
    }

    private func write(_ line: String) {
        if handle == nil {
            if !FileManager.default.fileExists(atPath: currentURL.path) {
                FileManager.default.createFile(atPath: currentURL.path, contents: nil)
            }
            handle = try? FileHandle(forWritingTo: currentURL)
            if let handle { _ = try? handle.seekToEnd() }
        }
        guard let handle, let data = line.data(using: .utf8) else { return }
        try? handle.write(contentsOf: data)
        if let size = try? FileManager.default.attributesOfItem(atPath: currentURL.path)[.size] as? UInt64,
           size > maxBytes {
            rotate()
        }
    }

    private func rotate() {
        try? handle?.close()
        handle = nil
        try? FileManager.default.removeItem(at: previousURL)
        try? FileManager.default.moveItem(at: currentURL, to: previousURL)
    }
}
