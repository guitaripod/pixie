import WidgetKit
import SwiftUI
import ActivityKit

@main
struct PixieWidgetExtension: WidgetBundle {
    var body: some Widget {
        if #available(iOS 16.2, *) {
            ImageGenerationLiveActivity()
        }
    }
}