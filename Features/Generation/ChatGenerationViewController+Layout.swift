import UIKit

extension ChatGenerationViewController {
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.horizontalSizeClass != previousTraitCollection?.horizontalSizeClass ||
           traitCollection.verticalSizeClass != previousTraitCollection?.verticalSizeClass {
            updateLayoutForSizeClass()
        }
    }
    
    private func updateLayoutForSizeClass() {
        leadingConstraint?.constant = 0
        trailingConstraint?.constant = 0

        Motion.animate(0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    func setupKeyboardCommands() {
        addKeyCommand(UIKeyCommand(title: String(localized: "New Chat"),
                                  action: #selector(newChatTapped),
                                  input: "N",
                                  modifierFlags: .command))
        
        addKeyCommand(UIKeyCommand(title: String(localized: "Generate"),
                                  action: #selector(generateWithKeyboard),
                                  input: "\r",
                                  modifierFlags: .command))
        
        addKeyCommand(UIKeyCommand(title: String(localized: "Open Gallery"),
                                  action: #selector(galleryTapped),
                                  input: "G",
                                  modifierFlags: .command))
        
        addKeyCommand(UIKeyCommand(title: String(localized: "Save Image"),
                                  action: #selector(saveCurrentImage),
                                  input: "S",
                                  modifierFlags: .command))
        
        addKeyCommand(UIKeyCommand(title: String(localized: "Focus Input"),
                                  action: #selector(focusInputField),
                                  input: "L",
                                  modifierFlags: .command))
        
        addKeyCommand(UIKeyCommand(title: String(localized: "Toggle Sidebar"),
                                  action: #selector(toggleSidebarShortcut),
                                  input: "\\",
                                  modifierFlags: .command))
    }
    
    @objc private func generateWithKeyboard() {
        if let text = inputBar.getCurrentText(), !text.isEmpty {
            handleSendPrompt(text)
        }
    }
    
    @objc private func saveCurrentImage() {
        guard let lastMessage = viewModel.messages.last,
              !lastMessage.isUser,
              let firstImage = lastMessage.images?.first else { return }
        PhotoSavingService.shared.saveToLibrary([firstImage]) { [weak self] result in
            switch result {
            case .success:
                self?.haptics.notification(.success)
                Announce.say(String(localized: "Saved to Photos"))
            case .failure:
                self?.haptics.notification(.error)
                Announce.say(String(localized: "Save Failed"))
            }
        }
    }
    
    @objc private func focusInputField() {
        inputBar.becomeFirstResponder()
    }
    
    @objc private func toggleSidebarShortcut() {
        if let splitVC = self.splitViewController as? MainSplitViewController {
            if splitVC.displayMode == .oneBesideSecondary {
                splitVC.preferredDisplayMode = .secondaryOnly
            } else {
                splitVC.preferredDisplayMode = .oneBesideSecondary
            }
        }
    }
    
    func setupDragAndDrop() {
        view.addInteraction(UIDropInteraction(delegate: self))
        chatView.addInteraction(UIDragInteraction(delegate: self))
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
}
