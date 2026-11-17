import Foundation
import MidgarCore
import UIKit

/// Whether PixiePocket's model features (image making and editing, photo ideas) work where this device connects from,
/// as Midgar's gateway answered. Everything that asks mako hides while it is false; on-device work is never affected.
nonisolated enum ModelFeatures {
    /// True until the gateway says otherwise, so a device that never reached Midgar keeps every feature.
    static var isAvailable: Bool {
        MidgarModelRegion.shared.modelsAvailable
    }

    /// Asks the gateway at launch and each time the app returns to the foreground, with the app's own gateway client.
    /// Nothing waits on the answer.
    static func startTracking() {
        Task { await refresh() }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            Task { await refresh() }
        }
    }

    private static func refresh() async {
        await MidgarModelRegion.shared.refresh(client: PixieMidgar.shared.account)
    }
}

/// Calls its handler on the main actor each time the model region answer flips, for as long as it is held.
nonisolated final class ModelFeatureObservation {
    private let token: NSObjectProtocol

    init(_ onChange: @escaping @MainActor () -> Void) {
        token = NotificationCenter.default.addObserver(
            forName: MidgarModelRegion.didChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { onChange() }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(token)
    }
}
