import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.2, *)
struct ImageGenerationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ImageGenerationAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color(UIColor.systemBackground))
                .activitySystemActionForegroundColor(Color(UIColor.label))
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        Image(systemName: context.attributes.isEdit ? "wand.and.stars" : "sparkles")
                            .foregroundColor(.purple)
                            .font(.title2)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    ProgressView(value: context.state.progress)
                        .progressViewStyle(.circular)
                        .tint(.purple)
                        .scaleEffect(0.8)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    if context.state.status == .completed || context.state.status == .failed {
                        VStack(spacing: 4) {
                            Text(context.state.status == .completed ? "Ready to view!" : "Generation failed")
                                .font(.headline)
                                .foregroundColor(statusColor(for: context.state.status))
                            Text(context.attributes.prompt)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text(context.attributes.prompt)
                            .font(.headline)
                            .lineLimit(2)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.status == .completed {
                        HStack {
                            Label("Tap to view", systemImage: "hand.tap.fill")
                                .font(.caption)
                                .foregroundColor(.purple)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                    } else if let error = context.state.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(2)
                    } else {
                        HStack {
                            Label(context.state.status.rawValue, systemImage: statusIcon(for: context.state.status))
                                .font(.caption)
                                .foregroundColor(statusColor(for: context.state.status))
                            
                            Spacer()
                            
                            if let timeRemaining = context.state.estimatedTimeRemaining {
                                Text("\(timeRemaining)s")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: statusIcon(for: context.state.status))
                    .foregroundColor(statusColor(for: context.state.status))
                    .font(.caption)
            } compactTrailing: {
                if context.state.status == .completed || context.state.status == .failed {
                    Image(systemName: context.state.status == .completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(statusColor(for: context.state.status))
                        .font(.caption)
                } else {
                    ProgressView(value: context.state.progress)
                        .progressViewStyle(.circular)
                        .tint(.purple)
                        .scaleEffect(0.6)
                }
            } minimal: {
                if context.state.status == .completed || context.state.status == .failed {
                    Image(systemName: context.state.status == .completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(statusColor(for: context.state.status))
                        .font(.caption)
                } else {
                    ProgressView(value: context.state.progress)
                        .progressViewStyle(.circular)
                        .tint(.purple)
                        .scaleEffect(0.6)
                }
            }
            .widgetURL(URL(string: "pixie://chat/\(context.attributes.chatId)"))
            .keylineTint(.purple)
        }
    }
    
    private func statusIcon(for status: GenerationStatus) -> String {
        switch status {
        case .queued:
            return "clock"
        case .processing:
            return "gearshape.2"
        case .generating:
            return "sparkles"
        case .completed:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
    
    private func statusColor(for status: GenerationStatus) -> Color {
        switch status {
        case .queued:
            return .orange
        case .processing, .generating:
            return .purple
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<ImageGenerationAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: context.attributes.isEdit ? "wand.and.stars" : "sparkles")
                        .foregroundColor(.purple)
                    Text(context.attributes.isEdit ? "Editing Image" : "Generating Image")
                        .font(.headline)
                }
                
                Spacer()
                
                if context.state.status != .completed && context.state.status != .failed {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                        .tint(.purple)
                }
            }
            
            Text(context.attributes.prompt)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Label(context.state.status.rawValue, systemImage: statusIcon(for: context.state.status))
                    .font(.caption)
                    .foregroundColor(statusColor(for: context.state.status))
                
                Spacer()
                
                if context.state.status != .completed && context.state.status != .failed {
                    ProgressBar(progress: context.state.progress)
                        .frame(width: 100, height: 4)
                    
                    if let timeRemaining = context.state.estimatedTimeRemaining {
                        Text("\(timeRemaining)s")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if let error = context.state.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
        }
        .padding()
    }
    
    private func statusIcon(for status: GenerationStatus) -> String {
        switch status {
        case .queued:
            return "clock"
        case .processing:
            return "gearshape.2"
        case .generating:
            return "sparkles"
        case .completed:
            return "checkmark.circle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }
    
    private func statusColor(for status: GenerationStatus) -> Color {
        switch status {
        case .queued:
            return .orange
        case .processing, .generating:
            return .purple
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}

struct ProgressBar: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.purple)
                    .frame(width: geometry.size.width * CGFloat(progress))
                    .animation(.linear(duration: 0.3), value: progress)
            }
        }
    }
}