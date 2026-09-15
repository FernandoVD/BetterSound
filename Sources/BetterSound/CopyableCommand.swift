import AppKit
import SwiftUI

/// A small monospaced command snippet with a one-click copy button. Used
/// for the update-available prompt: `brew install` a second time silently
/// does nothing (Homebrew just says "already installed" even when it
/// isn't), so pointing people straight at the exact `brew upgrade` command
/// beats sending them to a webpage and hoping they know the difference.
struct CopyableCommand: View {
    let command: String

    @State private var didCopy = false

    var body: some View {
        HStack(spacing: 6) {
            Text(command)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Button {
                copy()
            } label: {
                Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(didCopy ? Color.green : .secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func copy() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(command, forType: .string)

        didCopy = true
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            didCopy = false
        }
    }
}
