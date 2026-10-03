import UIKit

enum CenteredScrollContent {
    /// Wraps `content` in a scroll view pinned to `host`'s safe area. Content shorter than
    /// the screen is centered; taller content (large Dynamic Type, small phones) scrolls.
    @discardableResult
    static func make(containing content: UIView, in host: UIView, horizontalInset: CGFloat) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = false

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(container)
        container.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false

        host.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: host.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: host.bottomAnchor),

            container.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            container.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            container.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            container.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor),

            content.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            content.topAnchor.constraint(greaterThanOrEqualTo: container.topAnchor, constant: 20),
            content.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -20),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: horizontalInset),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -horizontalInset),
        ])
        return scrollView
    }
}
