import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

@available(iOS 16.2, *)
struct ImageGenerationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ImageGenerationAttributes.self) { context in
            LockScreenView(card: Card(context))
                .activityBackgroundTint(Color(UIColor.systemBackground))
                .activitySystemActionForegroundColor(Color(UIColor.label))
        } dynamicIsland: { context in
            let card = Card(context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Thumbnail(card: card, side: 48)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TrailingMark(card: card, font: .title3)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.title)
                            .font(.headline)
                            .foregroundStyle(card.tint)
                            .lineLimit(1)
                        Text(card.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Footer(card: card)
                        .padding(.horizontal, 4)
                }
            } compactLeading: {
                Thumbnail(card: card, side: 22)
            } compactTrailing: {
                TrailingMark(card: card, font: .caption)
            } minimal: {
                if card.isWorking {
                    ProgressView(
                        timerInterval: card.state.startedAt...card.state.expectedEnd,
                        countsDown: false, label: { EmptyView() }, currentValueLabel: { EmptyView() }
                    )
                    .progressViewStyle(.circular)
                    .tint(.purple)
                } else {
                    Thumbnail(card: card, side: 22)
                }
            }
            .widgetURL(URL(string: "pixie://chat/\(context.attributes.chatId)"))
            .keylineTint(.purple)
        }
    }
}

private struct Card {
    let attributes: ImageGenerationAttributes
    let state: ImageGenerationAttributes.ContentState
    let isStale: Bool

    init(_ context: ActivityViewContext<ImageGenerationAttributes>) {
        attributes = context.attributes
        state = context.state
        isStale = context.isStale
    }

    var phase: ImageGenerationAttributes.ContentState.Phase {
        state.phase == .working && isStale ? .paused : state.phase
    }

    var isWorking: Bool { phase == .working }

    var title: String {
        switch phase {
        case .working:
            return attributes.isEdit ? String(localized: "Editing Image") : String(localized: "Generating Image")
        case .ready: return String(localized: "Ready to view!")
        case .failed: return String(localized: "Generation failed")
        case .paused: return String(localized: "Open Pixie to finish")
        }
    }

    var detail: String {
        phase == .failed ? state.message ?? attributes.prompt : attributes.prompt
    }

    var tint: Color {
        switch phase {
        case .working: return .primary
        case .ready: return .green
        case .failed: return .red
        case .paused: return .orange
        }
    }

    var symbol: String {
        switch phase {
        case .working: return attributes.isEdit ? "wand.and.stars" : "sparkles"
        case .ready: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .paused: return "pause.circle.fill"
        }
    }

    var picture: UIImage? {
        let name = phase == .ready ? state.resultFile ?? attributes.sourceFile : attributes.sourceFile
        guard let name, let url = GenerationActivityFiles.url(for: name) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

private struct Thumbnail: View {
    let card: Card
    let side: CGFloat

    var body: some View {
        if let picture = card.picture {
            Image(uiImage: picture)
                .resizable()
                .scaledToFill()
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: side * 0.24, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    if !card.isWorking, side >= 40 {
                        Image(systemName: card.symbol)
                            .font(.system(size: side * 0.3, weight: .bold))
                            .foregroundStyle(.white, card.tint)
                            .offset(x: side * 0.1, y: side * 0.1)
                    }
                }
                .accessibilityHidden(true)
        } else {
            Image(systemName: card.symbol)
                .font(.system(size: side * 0.55, weight: .semibold))
                .foregroundStyle(card.isWorking ? .purple : card.tint)
                .frame(width: side, height: side)
                .accessibilityHidden(true)
        }
    }
}

private struct TrailingMark: View {
    let card: Card
    let font: Font

    var body: some View {
        switch card.phase {
        case .working:
            Text(timerInterval: card.state.startedAt...Date.distantFuture, countsDown: false)
                .font(font.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.purple)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 52)
        case .ready, .failed, .paused:
            Image(systemName: card.symbol)
                .font(font)
                .foregroundStyle(card.tint)
                .accessibilityLabel(card.title)
        }
    }
}

private struct Footer: View {
    let card: Card

    var body: some View {
        switch card.phase {
        case .working:
            VStack(spacing: 6) {
                ProgressView(
                    timerInterval: card.state.startedAt...card.state.expectedEnd,
                    countsDown: false, label: { EmptyView() }, currentValueLabel: { EmptyView() }
                )
                .tint(.purple)
                if let model = card.attributes.modelName {
                    Text(model)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        case .ready:
            Label(String(localized: "Tap to view"), systemImage: "hand.tap.fill")
                .font(.caption)
                .foregroundStyle(.purple)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .failed, .paused:
            EmptyView()
        }
    }
}

private struct LockScreenView: View {
    let card: Card

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Thumbnail(card: card, side: 56)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(card.title)
                        .font(.headline)
                        .foregroundStyle(card.tint)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    TrailingMark(card: card, font: .subheadline)
                }
                Text(card.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Footer(card: card)
                    .padding(.top, 2)
            }
        }
        .padding(16)
    }
}
