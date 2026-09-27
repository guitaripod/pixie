import ActivityKit
import UIKit
import UserNotifications

/// Follows one image generation on the Lock Screen and in the Dynamic Island, and keeps the app
/// running long enough for the card to reach an ending.
///
/// A card is only worth showing while nobody is looking at Pixie: a result that lands with the
/// app in front ends its card at once, and coming back to the app takes down whatever finished
/// while it was away. A result that lands in the background lights the card up with an alert,
/// then leaves the Dynamic Island and waits on the Lock Screen for `lockScreenLinger`. Without a
/// card to carry it, the same news goes out as a notification.
@MainActor
final class GenerationActivity {
    static let shared = GenerationActivity()

    private struct Run {
        let id: UUID
        let chatId: String
        let prompt: String
        let model: ImageModel?
        let startedAt: Date
        let expectedDuration: TimeInterval
        var activity: Activity<ImageGenerationAttributes>?
        var working = true
    }

    private var run: Run?
    private var finishing: [UUID: Task<Void, Never>] = [:]
    private var backgroundTasks: [UUID: UIBackgroundTaskIdentifier] = [:]

    init() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.appDidBecomeActive() }
        }
    }

    private static let lockScreenLinger: TimeInterval = 60 * 60
    private static let alertHold: TimeInterval = 8
    private static let thumbnailSide: CGFloat = 180
    private static let fileLifetime: TimeInterval = 6 * 60 * 60

    func begin(chatId: String, prompt: String, isEdit: Bool, model: ImageModel?, source: UIImage?)
        -> UUID
    {
        if let previous = run { cancel(previous.id) }
        let id = UUID()
        let startedAt = Date()
        let expected = GenerationDurations.expected(for: model)
        var run = Run(
            id: id, chatId: chatId, prompt: Self.shortened(prompt), model: model,
            startedAt: startedAt, expectedDuration: expected)
        backgroundTasks[id] = UIApplication.shared.beginBackgroundTask(withName: "Pixie generation") {
            [weak self] in
            MainActor.assumeIsolated { self?.pause(id) }
        }
        run.activity = requestCard(
            chatId: chatId, prompt: run.prompt, isEdit: isEdit, model: model, source: source, id: id,
            startedAt: startedAt, expected: expected)
        self.run = run
        return id
    }

    func succeed(_ id: UUID?, images: [UIImage]) {
        guard let id, var run = run, run.id == id else { return }
        run.working = false
        self.run = run
        if let model = run.model {
            GenerationDurations.record(Date().timeIntervalSince(run.startedAt), for: model)
        }
        let endedAt = Date()
        conclude(
            run,
            state: ImageGenerationAttributes.ContentState(
                phase: .ready, startedAt: run.startedAt, expectedDuration: run.expectedDuration,
                endedAt: endedAt,
                resultFile: images.first.flatMap { Self.writeThumbnail($0, name: "result-\(id).jpg") }),
            alert: AlertConfiguration(
                title: LocalizedStringResource("Image Generation Complete"),
                body: LocalizedStringResource("Your image for \"\(run.prompt)\" is ready!"),
                sound: .default),
            notification: (
                String(localized: "Image Generation Complete"),
                String(localized: "Your image for \"\(run.prompt)\" is ready!")
            ))
    }

    func fail(_ id: UUID?, error: GenerationError) {
        guard let id, var run = run, run.id == id else { return }
        run.working = false
        self.run = run
        let reason = error.localizedDescription
        let endedAt = Date()
        conclude(
            run,
            state: ImageGenerationAttributes.ContentState(
                phase: .failed, startedAt: run.startedAt, expectedDuration: run.expectedDuration,
                endedAt: endedAt, message: reason),
            alert: AlertConfiguration(
                title: LocalizedStringResource("Image Generation Failed"),
                body: LocalizedStringResource(stringLiteral: reason), sound: .default),
            notification: (String(localized: "Image Generation Failed"), reason))
    }

    /// Somebody stopped the generation, or left the screen that was waiting for it. Nobody needs
    /// telling about either, so the card simply goes.
    func cancel(_ id: UUID?) {
        guard let id, let run = run, run.id == id else { return }
        self.run = nil
        if let activity = run.activity {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        endBackgroundTask(run.id)
        AppLogger.info("Live Activity cancelled", category: .generation)
    }

    /// Pixie came to the front, so every result a card was announcing is on screen now: every card
    /// but the one following a generation still under way goes, including any a previous process
    /// left behind.
    private func appDidBecomeActive() {
        let live = run.flatMap { $0.working ? $0.activity?.id : nil }
        for task in finishing.values { task.cancel() }
        let settled = Activity<ImageGenerationAttributes>.activities.filter { $0.id != live }
        for activity in settled {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        if !settled.isEmpty {
            AppLogger.info("Live Activity: \(settled.count) finished card(s) taken down", category: .generation)
        }
    }

    private func requestCard(
        chatId: String, prompt: String, isEdit: Bool, model: ImageModel?, source: UIImage?,
        id: UUID, startedAt: Date, expected: TimeInterval
    ) -> Activity<ImageGenerationAttributes>? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }
        Self.sweepFiles()
        let attributes = ImageGenerationAttributes(
            chatId: chatId, prompt: prompt, isEdit: isEdit,
            modelName: model?.displayName,
            sourceFile: source.flatMap { Self.writeThumbnail($0, name: "source-\(id).jpg") })
        let state = ImageGenerationAttributes.ContentState(
            phase: .working, startedAt: startedAt, expectedDuration: expected)
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(
                    state: state, staleDate: startedAt.addingTimeInterval(max(expected * 4, 180))),
                pushType: nil)
            AppLogger.info("Live Activity started", category: .generation)
            return activity
        } catch {
            AppLogger.error(
                "Live Activity refused: \(error.localizedDescription)", category: .generation)
            return nil
        }
    }

    /// How a run's card ends. With Pixie in front the result is already on screen, so the card
    /// goes at once. Otherwise the card announces the ending with an alert, holds the Dynamic
    /// Island long enough for the alert to be seen, then leaves it and waits on the Lock Screen.
    private func conclude(
        _ run: Run, state: @autoclosure () -> ImageGenerationAttributes.ContentState,
        alert: AlertConfiguration, notification: (title: String, body: String)
    ) {
        let inFront = UIApplication.shared.applicationState == .active
        guard let activity = run.activity, activity.activityState == .active || activity.activityState == .stale
        else {
            if !inFront { post(notification, chatId: run.chatId, id: run.id) }
            self.run = nil
            endBackgroundTask(run.id)
            return
        }
        if inFront {
            self.run = nil
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
            endBackgroundTask(run.id)
            AppLogger.info("Live Activity ended with Pixie in front", category: .generation)
            return
        }
        let state = state()
        let content = ActivityContent(state: state, staleDate: nil, relevanceScore: 100)
        let leaves = Date().addingTimeInterval(Self.lockScreenLinger)
        let hold = max(0, min(Self.alertHold, UIApplication.shared.backgroundTimeRemaining - 3))
        finishing[run.id] = Task { [weak self] in
            await activity.update(content, alertConfiguration: alert)
            try? await Task.sleep(for: .seconds(hold))
            if !Task.isCancelled { await activity.end(content, dismissalPolicy: .after(leaves)) }
            self?.finished(run.id)
        }
        AppLogger.info("Live Activity \(state.phase.rawValue) in the background", category: .generation)
    }

    private func finished(_ id: UUID) {
        finishing[id] = nil
        if run?.id == id { run = nil }
        endBackgroundTask(id)
    }

    /// The system is about to suspend Pixie before the image arrived. The card stops claiming a
    /// generation is under way and says what will finish it, and leaves the Dynamic Island.
    private func pause(_ id: UUID) {
        guard var run = run, run.id == id else { return }
        if let activity = run.activity, run.working {
            let state = ImageGenerationAttributes.ContentState(
                phase: .paused, startedAt: run.startedAt, expectedDuration: run.expectedDuration)
            let content = ActivityContent(state: state, staleDate: nil)
            let leaves = Date().addingTimeInterval(Self.lockScreenLinger)
            Task { await activity.end(content, dismissalPolicy: .after(leaves)) }
            run.activity = nil
            AppLogger.info("Live Activity paused: background time ran out", category: .generation)
        }
        self.run = run
        endBackgroundTask(id)
    }

    private func endBackgroundTask(_ id: UUID) {
        guard let task = backgroundTasks.removeValue(forKey: id), task != .invalid else { return }
        UIApplication.shared.endBackgroundTask(task)
    }

    private func post(_ notification: (title: String, body: String), chatId: String, id: UUID) {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.userInfo = ["chatId": chatId, "type": "generation_complete"]
        let request = UNNotificationRequest(identifier: id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private static func shortened(_ prompt: String) -> String {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 120 else { return trimmed }
        return String(trimmed.prefix(119)) + "…"
    }

    private static func writeThumbnail(_ image: UIImage, name: String) -> String? {
        guard let directory = GenerationActivityFiles.directory,
            let url = GenerationActivityFiles.url(for: name)
        else { return nil }
        let scale = min(1, thumbnailSide / max(image.size.width, image.size.height, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let thumbnail = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = thumbnail.jpegData(compressionQuality: 0.8) else { return nil }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            return name
        } catch {
            AppLogger.error("Live Activity thumbnail not written: \(error.localizedDescription)", category: .generation)
            return nil
        }
    }

    private static func sweepFiles() {
        guard let directory = GenerationActivityFiles.directory,
            let files = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.contentModificationDateKey])
        else { return }
        let cutoff = Date().addingTimeInterval(-fileLifetime)
        for file in files {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
            if let modified, modified < cutoff { try? FileManager.default.removeItem(at: file) }
        }
    }
}

/// How long a generation on each model takes on this device, from the last few that finished, so
/// a card's progress bar fills over a real expectation rather than a guess.
enum GenerationDurations {
    private static let keep = 5

    static func expected(for model: ImageModel?) -> TimeInterval {
        guard let model else { return 20 }
        let history = UserDefaults.standard.array(forKey: key(model)) as? [Double] ?? []
        guard !history.isEmpty else { return fallback(model) }
        return history.sorted()[history.count / 2]
    }

    static func record(_ duration: TimeInterval, for model: ImageModel) {
        guard duration > 1, duration < 600 else { return }
        var history = UserDefaults.standard.array(forKey: key(model)) as? [Double] ?? []
        history.append(duration)
        UserDefaults.standard.set(Array(history.suffix(keep)), forKey: key(model))
    }

    private static func fallback(_ model: ImageModel) -> TimeInterval {
        switch model {
        case .gemini: return 12
        case .geminiPro: return 25
        case .openai: return 45
        }
    }

    private static func key(_ model: ImageModel) -> String {
        "generationDurations.\(model.rawValue)"
    }
}
