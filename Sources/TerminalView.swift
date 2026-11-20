import UIKit

final class TerminalView: UIView, UIKeyInput {

    private let text = UITextView()
    private var line = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black

        text.backgroundColor = .black
        text.textColor = .white
        text.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        text.isEditable = false
        text.alwaysBounceVertical = true
        text.textContainerInset = .init(top: 8, left: 0, bottom: 8, right: 0)
        text.text = "$ "
        text.translatesAutoresizingMaskIntoConstraints = false
        addSubview(text)

        NSLayoutConstraint.activate([
            text.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            text.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            text.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            text.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(focus)))
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func focus() { becomeFirstResponder() }

    func append(_ s: String) {
        text.text += s
        text.scrollRangeToVisible(NSRange(location: text.text.utf16.count, length: 0))
    }

    override var canBecomeFirstResponder: Bool { true }
    var hasText: Bool { true }
    var keyboardType: UIKeyboardType = .asciiCapable
    var autocorrectionType: UITextAutocorrectionType = .no
    var autocapitalizationType: UITextAutocapitalizationType = .none
    var spellCheckingType: UITextSpellCheckingType = .no
    var smartQuotesType: UITextSmartQuotesType = .no
    var smartDashesType: UITextSmartDashesType = .no
    var smartInsertDeleteType: UITextSmartInsertDeleteType = .no
    var returnKeyType: UIReturnKeyType = .default

    func insertText(_ t: String) {
        guard t != "\n" else {
            append("\n")
            Shell.shared.write(line + "\n")
            line = ""
            return
        }
        line += t
        append(t)
    }

    func deleteBackward() {
        guard !line.isEmpty else { return }
        line.removeLast()
        text.text.removeLast()
    }

    override var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand(input: "\u{03}", modifierFlags: [], action: #selector(ctrlC))]
    }

    @objc private func ctrlC() {
        Shell.shared.interrupt()
        line = ""
    }
}
