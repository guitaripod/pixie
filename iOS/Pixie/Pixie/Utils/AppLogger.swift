import Foundation
import OSLog

enum AppLogger {
    enum Category: String, CaseIterable {
        case launch
        case generation
        case review
        case credits
        case auth
        case network
        case ui
        case general
    }

    private static let subsystem = Bundle.main.bundleIdentifier ?? "pixie"
    private static let writer = LogFileWriter.shared

    static var currentLogFileURL: URL { writer.currentURL }
    static var previousLogFileURL: URL { writer.previousURL }

    private static func logger(for category: Category) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }

    static func debug(_ message: String, category: Category = .general) {
        logger(for: category).debug("\(message, privacy: .public)")
        writer.append(level: "debug", category: category.rawValue, message: message)
    }

    static func info(_ message: String, category: Category = .general) {
        logger(for: category).info("\(message, privacy: .public)")
        writer.append(level: "info", category: category.rawValue, message: message)
    }

    static func warning(_ message: String, category: Category = .general) {
        logger(for: category).warning("\(message, privacy: .public)")
        writer.append(level: "warn", category: category.rawValue, message: message)
    }

    static func error(_ message: String, category: Category = .general) {
        logger(for: category).error("\(message, privacy: .public)")
        writer.append(level: "error", category: category.rawValue, message: message)
    }
}
