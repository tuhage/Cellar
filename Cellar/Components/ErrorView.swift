import SwiftUI
import CellarCore

/// Full-page error for a page with nothing to show: what failed, what to
/// try, and a way to retry or copy the details.
struct ErrorView: View {
    let message: String
    var suggestion: String?
    var retryAction: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(message, systemImage: "exclamationmark.triangle")
        } description: {
            if let suggestion = suggestion ?? Self.suggestion(for: message) {
                Text(AttributedString(markdownOrPlain: suggestion))
            }
        } actions: {
            if let retryAction {
                Button("Try Again", action: retryAction)
                    .buttonStyle(.borderedProminent)
            }
            Button("Copy Details") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message, forType: .string)
            }
            .buttonStyle(.borderless)
        }
        .transition(.opacity)
    }

    // MARK: - Suggestion Detection

    static func suggestion(for message: String) -> String? {
        let lowercased = message.lowercased()

        if lowercased.contains("homebrew not found") {
            return "Homebrew may not be installed. [Install it from brew.sh](https://brew.sh)."
        }
        if lowercased.contains("permission denied") {
            return "Homebrew needs your user to own its folders. Run `brew doctor` in Terminal to see which ones."
        }
        if lowercased.contains("timed out") || lowercased.contains("timeout") {
            return "The operation took too long. Check your internet connection and try again."
        }
        if lowercased.contains("could not resolve host") || lowercased.contains("network") {
            return "Check your internet connection and try again."
        }
        return nil
    }
}

private extension AttributedString {
    /// Renders inline Markdown (links, code) and falls back to plain text.
    init(markdownOrPlain string: String) {
        self = (try? AttributedString(markdown: string)) ?? AttributedString(string)
    }
}

#Preview("With Retry") {
    ErrorView(message: "Homebrew packages couldn’t be loaded.") {}
}

#Preview("Brew Not Found") {
    ErrorView(message: "Homebrew not found. Please install Homebrew first.")
}

#Preview("Permission Denied") {
    ErrorView(message: "Brew command failed (exit 1): permission denied")
}
