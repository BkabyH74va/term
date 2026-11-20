import SwiftUI

struct TerminalRepresentable: UIViewRepresentable {

    func makeUIView(context: Context) -> TerminalView {
        let v = TerminalView()
        Shell.shared.onOutput = { [weak v] s in v?.append(s) }
        Shell.shared.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { v.becomeFirstResponder() }
        return v
    }

    func updateUIView(_ uiView: TerminalView, context: Context) {}
}

@main
struct TerminalApp: App {
    var body: some Scene {
        WindowGroup {
            TerminalRepresentable().ignoresSafeArea(.container, edges: .bottom)
        }
    }
}
