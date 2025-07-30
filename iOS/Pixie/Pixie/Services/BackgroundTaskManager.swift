import UIKit
import BackgroundTasks
import UserNotifications
import Combine
import ActivityKit

class BackgroundTaskManager: NSObject {
    static let shared = BackgroundTaskManager()
    
    private let taskIdentifier = "com.guitaripod.Pixie.image-generation"
    private var activeTasks: [String: BackgroundGenerationTask] = [:]
    private let taskQueue = DispatchQueue(label: "com.guitaripod.Pixie.backgroundTasks", attributes: .concurrent)
    private var cancellables = Set<AnyCancellable>()
    private var liveActivities: [String: Activity<ImageGenerationAttributes>] = [:]
    
    struct BackgroundGenerationTask {
        let id: String
        let prompt: String
        let chatId: String
        let options: GenerationOptions?
        let editOptions: EditOptions?
        let imageUri: URL?
        let task: Task<Void, Never>?
        var backgroundTask: UIBackgroundTaskIdentifier?
    }
    
    override init() {
        super.init()
        registerBackgroundTasks()
        requestNotificationPermission()
    }
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleBackgroundTask(task as! BGProcessingTask)
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { _, _ in }
    }
    
    func scheduleBackgroundGeneration(
        prompt: String,
        chatId: String,
        options: GenerationOptions
    ) -> String {
        let taskId = UUID().uuidString
        
        startLiveActivity(taskId: taskId, prompt: prompt, chatId: chatId, isEdit: false)
        
        let backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.cleanupTask(taskId: taskId)
        }
        
        let generationService = GenerationService(apiService: AppContainer.shared.apiService)
        
        let task = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let result = await withCheckedContinuation { continuation in
                    _ = generationService.generateImages(
                        prompt: prompt,
                        options: options
                    ) { result in
                        continuation.resume(returning: result)
                    }
                }
                
                await self.updateLiveActivity(taskId: taskId, progress: 0.5, status: .generating)
                
                switch result {
                case .success(let images):
                    await self.updateLiveActivity(taskId: taskId, progress: 1.0, status: .completed)
                    await self.handleGenerationSuccess(
                        taskId: taskId,
                        chatId: chatId,
                        prompt: prompt,
                        images: images
                    )
                case .failure(let error):
                    await self.updateLiveActivity(taskId: taskId, progress: 0.0, status: .failed, error: error.localizedDescription)
                    await self.handleGenerationFailure(
                        taskId: taskId,
                        chatId: chatId,
                        prompt: prompt,
                        error: error
                    )
                }
            }
            
            await MainActor.run {
                self.cleanupTask(taskId: taskId)
            }
        }
        
        let backgroundTask = BackgroundGenerationTask(
            id: taskId,
            prompt: prompt,
            chatId: chatId,
            options: options,
            editOptions: nil,
            imageUri: nil,
            task: task,
            backgroundTask: backgroundTaskIdentifier
        )
        
        taskQueue.async(flags: .barrier) {
            self.activeTasks[taskId] = backgroundTask
        }
        
        scheduleBackgroundTaskIfNeeded()
        
        return taskId
    }
    
    func scheduleBackgroundEdit(
        imageUri: URL,
        prompt: String,
        chatId: String,
        options: EditOptions
    ) -> String {
        let taskId = UUID().uuidString
        
        startLiveActivity(taskId: taskId, prompt: prompt, chatId: chatId, isEdit: true)
        
        let backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.cleanupTask(taskId: taskId)
        }
        
        let generationService = GenerationService(apiService: AppContainer.shared.apiService)
        
        let task = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let result = await withCheckedContinuation { continuation in
                    _ = generationService.editImage(
                        imageUri: imageUri,
                        prompt: prompt,
                        options: options
                    ) { result in
                        continuation.resume(returning: result)
                    }
                }
                
                await self.updateLiveActivity(taskId: taskId, progress: 0.5, status: .generating)
                
                switch result {
                case .success(let images):
                    await self.updateLiveActivity(taskId: taskId, progress: 1.0, status: .completed)
                    await self.handleGenerationSuccess(
                        taskId: taskId,
                        chatId: chatId,
                        prompt: prompt,
                        images: images
                    )
                case .failure(let error):
                    await self.updateLiveActivity(taskId: taskId, progress: 0.0, status: .failed, error: error.localizedDescription)
                    await self.handleGenerationFailure(
                        taskId: taskId,
                        chatId: chatId,
                        prompt: prompt,
                        error: error
                    )
                }
            }
            
            await MainActor.run {
                self.cleanupTask(taskId: taskId)
            }
        }
        
        let backgroundTask = BackgroundGenerationTask(
            id: taskId,
            prompt: prompt,
            chatId: chatId,
            options: nil,
            editOptions: options,
            imageUri: imageUri,
            task: task,
            backgroundTask: backgroundTaskIdentifier
        )
        
        taskQueue.async(flags: .barrier) {
            self.activeTasks[taskId] = backgroundTask
        }
        
        scheduleBackgroundTaskIfNeeded()
        
        return taskId
    }
    
    private func scheduleBackgroundTaskIfNeeded() {
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
        }
    }
    
    func handleBackgroundTask(_ task: BGProcessingTask) {
        task.expirationHandler = { [weak self] in
            self?.handleTaskExpiration()
            task.setTaskCompleted(success: false)
        }
        
        Task {
            let hasPendingTasks = taskQueue.sync { !activeTasks.isEmpty }
            
            if hasPendingTasks {
                await withTaskGroup(of: Void.self) { group in
                    for (_, activeTask) in activeTasks {
                        if let task = activeTask.task {
                            group.addTask {
                                await task.value
                            }
                        }
                    }
                }
            }
            
            task.setTaskCompleted(success: true)
        }
    }
    
    private func handleGenerationSuccess(
        taskId: String,
        chatId: String,
        prompt: String,
        images: [UIImage]
    ) async {
        await saveGeneratedImages(images: images, chatId: chatId)
        
        if await shouldUseLiveActivityAlert() {
            await expandLiveActivityForCompletion(
                taskId: taskId, 
                prompt: prompt, 
                success: true,
                chatId: chatId
            )
        } else {
            await sendNotification(
                title: "Image Generation Complete",
                body: "Your image for \"\(prompt)\" is ready!",
                chatId: chatId,
                taskId: taskId,
                success: true
            )
        }
    }
    
    private func handleGenerationFailure(
        taskId: String,
        chatId: String,
        prompt: String,
        error: GenerationError
    ) async {
        if await shouldUseLiveActivityAlert() {
            await expandLiveActivityForCompletion(
                taskId: taskId, 
                prompt: prompt, 
                success: false, 
                error: error.localizedDescription,
                chatId: chatId
            )
        } else {
            await sendNotification(
                title: "Image Generation Failed",
                body: error.localizedDescription,
                chatId: chatId,
                taskId: taskId,
                success: false
            )
        }
    }
    
    private func saveGeneratedImages(images: [UIImage], chatId: String) async {
        for (index, image) in images.enumerated() {
            guard let data = image.pngData() else { continue }
            
            let fileName = "\(chatId)_\(UUID().uuidString)_\(index).png"
            let fileURL = FileManager.default
                .temporaryDirectory
                .appendingPathComponent(fileName)
            
            do {
                try data.write(to: fileURL)
            } catch {
            }
        }
    }
    
    private func sendNotification(
        title: String,
        body: String,
        chatId: String,
        taskId: String,
        success: Bool
    ) async {
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = success ? .default : .defaultCritical
        content.userInfo = [
            "chatId": chatId,
            "taskId": taskId,
            "type": "generation_complete"
        ]
        
        if success {
            content.categoryIdentifier = "GENERATION_COMPLETE"
        }
        
        let request = UNNotificationRequest(
            identifier: taskId,
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
        }
    }
    
    private func cleanupTask(taskId: String) {
        taskQueue.async(flags: .barrier) { [weak self] in
            if let task = self?.activeTasks[taskId] {
                task.task?.cancel()
                if let backgroundTaskId = task.backgroundTask {
                    UIApplication.shared.endBackgroundTask(backgroundTaskId)
                }
                self?.activeTasks.removeValue(forKey: taskId)
            }
        }
        
        Task {
            await endLiveActivity(taskId: taskId)
        }
    }
    
    private func handleTaskExpiration() {
        taskQueue.async(flags: .barrier) { [weak self] in
            for (taskId, _) in self?.activeTasks ?? [:] {
                self?.cleanupTask(taskId: taskId)
            }
        }
    }
    
    func cancelTask(taskId: String) {
        cleanupTask(taskId: taskId)
    }
    
    func getActiveTaskCount() -> Int {
        taskQueue.sync {
            activeTasks.count
        }
    }
    
    // MARK: - Live Activity Management
    
    private func startLiveActivity(taskId: String, prompt: String, chatId: String, isEdit: Bool) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }
        
        let attributes = ImageGenerationAttributes(
            prompt: prompt,
            taskId: taskId,
            chatId: chatId,
            isEdit: isEdit
        )
        
        let initialState = ImageGenerationAttributes.ContentState(
            progress: 0.1,
            status: .queued,
            estimatedTimeRemaining: 30,
            errorMessage: nil
        )
        
        let content = ActivityContent(state: initialState, staleDate: nil)
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            
            taskQueue.async(flags: .barrier) {
                self.liveActivities[taskId] = activity
            }
            
        } catch {
        }
    }
    
    private func updateLiveActivity(taskId: String, progress: Double, status: GenerationStatus, error: String? = nil) async {
        guard let activity = taskQueue.sync(execute: { liveActivities[taskId] }) else {
            return
        }
        
        let updatedState = ImageGenerationAttributes.ContentState(
            progress: progress,
            status: status,
            estimatedTimeRemaining: status == .generating ? Int(30 * (1 - progress)) : nil,
            errorMessage: error
        )
        
        let content = ActivityContent(state: updatedState, staleDate: nil)
        
        Task {
            await activity.update(content)
        }
    }
    
    private func endLiveActivity(taskId: String) async {
        guard let activity = taskQueue.sync(execute: { liveActivities[taskId] }) else { return }
        
        await activity.end(nil, dismissalPolicy: .default)
        
        taskQueue.async(flags: .barrier) { [weak self] in
            self?.liveActivities.removeValue(forKey: taskId)
        }
    }
    
    @MainActor
    private func shouldUseLiveActivityAlert() -> Bool {
        if #available(iOS 16.2, *) {
            let isInBackground = UIApplication.shared.applicationState == .background
            let hasActiveLiveActivity = !liveActivities.isEmpty
            let liveActivitiesEnabled = ActivityAuthorizationInfo().areActivitiesEnabled
            
            return isInBackground && hasActiveLiveActivity && liveActivitiesEnabled
        }
        return false
    }
    
    private func expandLiveActivityForCompletion(
        taskId: String,
        prompt: String,
        success: Bool,
        error: String? = nil,
        chatId: String
    ) async {
        guard let activity = taskQueue.sync(execute: { liveActivities[taskId] }) else { 
            return
        }
        
        let finalState = ImageGenerationAttributes.ContentState(
            progress: 1.0,
            status: success ? .completed : .failed,
            estimatedTimeRemaining: nil,
            errorMessage: error
        )
        
        await activity.update(
            ActivityContent(
                state: finalState,
                staleDate: nil,
                relevanceScore: 100
            )
        )
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            Task {
                await self?.endLiveActivity(taskId: taskId)
            }
        }
    }
}

extension BackgroundTaskManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        if let chatId = userInfo["chatId"] as? String,
           userInfo["type"] as? String == "generation_complete" {
            NotificationCenter.default.post(
                name: .openChatFromNotification,
                object: nil,
                userInfo: ["chatId": chatId]
            )
        }
        
        completionHandler()
    }
}

extension Notification.Name {
    static let openChatFromNotification = Notification.Name("openChatFromNotification")
}