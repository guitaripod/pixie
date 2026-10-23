import UIKit

/// A label that rolls from one whole number to the next instead of jumping, so a balance that
/// changes reads as money arriving or leaving.
final class CountingLabel: UILabel {
    private static let minimumDuration: TimeInterval = 0.45
    private static let maximumDuration: TimeInterval = 1.1
    private static let firstValueDuration: TimeInterval = 0.7

    private(set) var value: Int?
    private var format: (Int) -> String = { NumberFormatter.localizedString(from: NSNumber(value: $0), number: .decimal) }
    private var link: CADisplayLink?
    private var displayed = 0
    private var startValue = 0
    private var targetValue = 0
    private var startTime: CFTimeInterval = 0
    private var duration: TimeInterval = 0

    isolated deinit { link?.invalidate() }

    /// Shows `newValue`, counting from what is on screen when `animated` and motion is allowed.
    /// A first value counts up from zero; `nil` stops any count and shows `placeholder`.
    func setValue(_ newValue: Int?, placeholder: String = "—", format: @escaping (Int) -> String, animated: Bool) {
        self.format = format
        guard let newValue else {
            stop()
            value = nil
            text = placeholder
            return
        }
        if newValue == value, link != nil { return }
        defer { value = newValue }
        guard animated, !Motion.isReduced, newValue != value else {
            stop()
            show(newValue)
            return
        }
        let from = link == nil ? (value ?? 0) : displayed
        let span = TimeInterval(abs(newValue - from))
        let isFirst = value == nil
        start(from: from, to: newValue, duration: isFirst ? Self.firstValueDuration : min(Self.maximumDuration, max(Self.minimumDuration, span.squareRoot() / 40)))
    }

    private func start(from: Int, to: Int, duration: TimeInterval) {
        stop()
        startValue = from
        targetValue = to
        self.duration = duration
        startTime = CACurrentMediaTime()
        show(from)
        let link = CADisplayLink(target: LinkTarget(self), selector: #selector(LinkTarget.tick))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    private func show(_ number: Int) {
        displayed = number
        text = format(number)
    }

    private func stop() {
        link?.invalidate()
        link = nil
    }

    fileprivate func advance() {
        let progress = min(1, (CACurrentMediaTime() - startTime) / duration)
        let eased = 1 - pow(1 - progress, 3)
        let current = startValue + Int((Double(targetValue - startValue) * eased).rounded())
        show(current)
        if progress >= 1 { stop() }
    }

    /// Gives every digit the same width; call after the label's font is set.
    func monospaceDigits() {
        let features: [[UIFontDescriptor.FeatureKey: Int]] = [[
            .type: kNumberSpacingType,
            .selector: kMonospacedNumbersSelector,
        ]]
        let descriptor = font.fontDescriptor.addingAttributes([.featureSettings: features])
        font = UIFont(descriptor: descriptor, size: font.pointSize)
    }
}

/// Keeps the display link from retaining the label it drives, so the label can deallocate mid-count.
private final class LinkTarget {
    private weak var label: CountingLabel?

    init(_ label: CountingLabel) { self.label = label }

    @objc func tick(_ link: CADisplayLink) {
        guard let label else {
            link.invalidate()
            return
        }
        label.advance()
    }
}
