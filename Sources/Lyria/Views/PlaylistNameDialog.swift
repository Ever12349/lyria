import AppKit
import SwiftUI

struct PlaylistNameDialog: View {
    @EnvironmentObject private var store: AppSession
    @State private var name: String

    init(suggestedName: String) {
        _name = State(initialValue: suggestedName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新建播放列表")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(LyriaTheme.foreground)
            SelectingTextField(text: $name, onSubmit: commit)
                .frame(maxWidth: .infinity, minHeight: 24, maxHeight: 24)
            HStack(spacing: 8) {
                Spacer()
                Button("取消") { store.cancelNewPlaylist() }
                    .keyboardShortcut(.cancelAction)
                Button("创建", action: commit)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.commitNewPlaylist(named: trimmed)
    }
}

/// Prefills the suggested name and selects it. Whitespace-only submit stays in the dialog.
private struct SelectingTextField: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.delegate = context.coordinator
        field.isEditable = true
        field.isSelectable = true
        field.isBezeled = true
        field.font = .systemFont(ofSize: 13)
        field.target = context.coordinator
        field.action = #selector(Coordinator.submit)
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
            field.currentEditor()?.selectAll(nil)
        }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.onSubmit = onSubmit
        if field.currentEditor() == nil, field.stringValue != text {
            field.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var onSubmit: () -> Void

        init(text: Binding<String>, onSubmit: @escaping () -> Void) {
            self.text = text
            self.onSubmit = onSubmit
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        @objc func submit() {
            onSubmit()
        }
    }
}
