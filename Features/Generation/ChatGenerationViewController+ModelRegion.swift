import MidgarCore
import UIKit

extension ChatGenerationViewController {
    /// Puts the neutral line where the composer would be and follows the answer from Midgar's gateway from then on.
    func setupModelRegion() {
        regionNotice.translatesAutoresizingMaskIntoConstraints = false
        regionNotice.numberOfLines = 0
        regionNotice.textAlignment = .center
        regionNotice.apply(.footnote, color: Theme.Color.inkSecondary)
        regionNotice.text = MidgarModelRegion.unavailableMessage
        view.addSubview(regionNotice)
        NSLayoutConstraint.activate([
            regionNotice.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            regionNotice.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Theme.Space.lg),
            regionNotice.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Theme.Space.lg),
            regionNotice.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -Theme.Space.md)
        ])
        modelRegionObserver = ModelFeatureObservation { [weak self] in
            self?.applyModelRegion()
        }
        applyModelRegion()
    }

    /// Where model features do not work, the composer, the starter screen and the edits pill go, and the neutral line
    /// stays; where they work, all of it is shown as before.
    func applyModelRegion() {
        let isAvailable = ModelFeatures.isAvailable
        inputBar.isHidden = !isAvailable
        suggestionsView.isHidden = !isAvailable
        topBar.setCreditsHidden(!isAvailable)
        regionNotice.isHidden = isAvailable
    }
}
