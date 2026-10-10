import UIKit

final class ColumnScrollView: UIScrollView {
    let column = UIStackView()
    private var fillWidth: NSLayoutConstraint!
    private var appliedMargin = Theme.Space.xl

    init(maxWidth: CGFloat = Theme.Width.form, spacing: CGFloat = Theme.Space.xxl, topInset: CGFloat = Theme.Space.lg, bottomInset: CGFloat = Theme.Space.xxxl) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        alwaysBounceVertical = true
        column.axis = .vertical
        column.spacing = spacing
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)

        fillWidth = column.widthAnchor.constraint(equalTo: contentLayoutGuide.widthAnchor, constant: -2 * appliedMargin)
        fillWidth.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            contentLayoutGuide.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor),
            column.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor, constant: topInset),
            column.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor, constant: -bottomInset),
            column.centerXAnchor.constraint(equalTo: contentLayoutGuide.centerXAnchor),
            column.widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth),
            fillWidth,
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let margin = Theme.screenMargin(for: traitCollection)
        guard margin != appliedMargin else { return }
        appliedMargin = margin
        fillWidth.constant = -2 * margin
    }
}

final class ColumnContainer: UIView {
    private var fillWidth: NSLayoutConstraint!
    private var appliedMargin = Theme.Space.xl

    /// A view centred in `host`, at most `maxWidth` wide and inset by the screen margin, so list rows share the credits column.
    init(in host: UIView, maxWidth: CGFloat = Theme.Width.form, top: CGFloat = 0, bottom: CGFloat = 0) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(self)
        fillWidth = widthAnchor.constraint(equalTo: host.widthAnchor, constant: -2 * appliedMargin)
        fillWidth.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: host.topAnchor, constant: top),
            bottomAnchor.constraint(equalTo: host.bottomAnchor, constant: -bottom),
            centerXAnchor.constraint(equalTo: host.centerXAnchor),
            widthAnchor.constraint(lessThanOrEqualToConstant: maxWidth),
            fillWidth,
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let margin = Theme.screenMargin(for: traitCollection)
        guard margin != appliedMargin else { return }
        appliedMargin = margin
        fillWidth.constant = -2 * margin
    }
}

final class CreditsSectionHeader: UIView {
    private let titleLabel = UILabel()
    private let actionButton: PixieButton?
    private let stack = UIStackView()

    init(title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        if let actionTitle, let action {
            actionButton = PixieButton(style: .plain, size: .medium, title: actionTitle, handler: action)
        } else {
            actionButton = nil
        }
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setStyledText(title, .caption)
        titleLabel.accessibilityTraits = .header
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Theme.Space.sm
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(titleLabel)
        if let actionButton {
            actionButton.setContentHuggingPriority(.required, for: .horizontal)
            actionButton.setContentCompressionResistancePriority(.required, for: .horizontal)
            stack.addArrangedSubview(actionButton)
        }
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Theme.Space.xs),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: actionButton == nil ? 0 : 22),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let isAccessibilitySize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let axis: NSLayoutConstraint.Axis = isAccessibilitySize ? .vertical : .horizontal
        guard stack.axis != axis else { return }
        stack.axis = axis
        stack.alignment = isAccessibilitySize ? .leading : .center
    }
}

enum RowCard {
    /// A card holding `rows` separated by hairlines inset to the row text, so grouped rows read as one surface.
    static func make(_ rows: [UIView], dividerInset: CGFloat = Theme.Space.lg + 40 + Theme.Space.md) -> SurfaceView {
        let card = SurfaceView(style: .card, cornerRadius: Theme.Radius.lg)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        for (index, row) in rows.enumerated() {
            if index > 0 { stack.addArrangedSubview(RowDivider(inset: dividerInset)) }
            stack.addArrangedSubview(row)
        }
        card.contentView.addSubview(stack)
        stack.pinEdges(to: card.contentView)
        return card
    }
}

extension CreditTransaction {
    func makeListRow(stamp: String) -> ListRowView {
        let row = ListRowView(
            title: description,
            subtitle: stamp.isEmpty ? nil : stamp,
            value: signedAmountText,
            symbol: badgeSymbol,
            colors: badgeColors,
            valueColor: amountColor
        )
        row.isUserInteractionEnabled = false
        row.accessibilityLabel = "\(kindName), \(description)"
        row.accessibilityValue = [spokenAmount, stamp].filter { !$0.isEmpty }.joined(separator: ", ")
        row.accessibilityTraits = .staticText
        return row
    }
}
