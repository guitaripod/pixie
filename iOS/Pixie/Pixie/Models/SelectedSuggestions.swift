import Foundation
import UIKit


enum SuggestionType {
    case quickAction
    case creativePrompt
    case stylePreset
    case promptModifier
}


struct SelectedSuggestion {
    let type: SuggestionType
    let title: String
    let prompt: String
    let color: UIColor
    let icon: String?
}


class SelectedSuggestionsManager: ObservableObject {
    @Published private(set) var selections: [SuggestionType: SelectedSuggestion] = [:]
    func setSelection(_ suggestion: SelectedSuggestion) {
        selections[suggestion.type] = suggestion
    }
    func removeSelection(for type: SuggestionType) {
        selections.removeValue(forKey: type)
    }
    func toggleSelection(_ suggestion: SelectedSuggestion) {
        if selections[suggestion.type]?.title == suggestion.title {
            removeSelection(for: suggestion.type)
        } else {
            setSelection(suggestion)
        }
    }
    func hasSelection(for type: SuggestionType) -> Bool {
        selections[type] != nil
    }
    func isSelected(_ title: String, type: SuggestionType) -> Bool {
        selections[type]?.title == title
    }
    func clearAll() {
        selections.removeAll()
    }
    func composePrompt(basePrompt: String) -> String {
        var components: [String] = []
        if !basePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            components.append(basePrompt)
        }
        if let quickAction = selections[.quickAction] {
            if components.isEmpty {
                components.append(quickAction.prompt)
            } else {
                components.append("Style: \(quickAction.prompt)")
            }
        }
        if let creative = selections[.creativePrompt] {
            if components.isEmpty {
                components.append(creative.prompt)
            } else {
                components.append("Theme: \(creative.prompt)")
            }
        }
        if let style = selections[.stylePreset] {
            components.append("Apply \(style.prompt)")
        }
        if let modifier = selections[.promptModifier] {
            components.append(modifier.prompt)
        }
        return components.joined(separator: ". ")
    }
    func getIndicatorColors() -> [UIColor] {
        var colors: [UIColor] = []
        if let quickAction = selections[.quickAction] {
            colors.append(quickAction.color)
        }
        if let creative = selections[.creativePrompt] {
            colors.append(creative.color)
        }
        if let style = selections[.stylePreset] {
            colors.append(style.color)
        }
        if let modifier = selections[.promptModifier] {
            colors.append(modifier.color)
        }
        return colors
    }
}

