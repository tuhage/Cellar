import SwiftUI
import CellarCore

struct ErrorView: View {
    let message: String
    var suggestion: String?
    var retryAction: (() -> Void)?

    private var resolvedSuggestion: String? {
        suggestion ?? Self.suggestion(for: message)
    }

    var body: some View {
        ContentUnavailableView {
            Label("Something Went Wrong", systemImage: "exclamationmark.triangle")
        } description: {
            VStack(spacing: 8) {
                Text(message)
                if let resolvedSuggestion {
                    Text(resolvedSuggestion)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
        } actions: {
            if let retryAction {
                Button("Retry", action: retryAction)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Suggestion Detection

    static func suggestion(for message: String) -> String? {
        let lowercased = message.lowercased()

        if lowercased.contains("not found") || lowercased.contains("no such file") {
            if lowercased.contains("brew") || lowercased.contains("homebrew") {
                return "Homebrew may not be installed. Visit https://brew.sh to install it."
            }
        }

        if lowercased.contains("permission denied") {
            return "Try running the operation with administrator privileges."
        }

        if lowercased.contains("timed out") || lowercased.contains("timeout") {
            return "The operation timed out. Check your internet connection and try again."
        }

        if lowercased.contains("could not resolve host") || lowercased.contains("network") {
            return "Check your internet connection and try again."
        }

        return nil
    }
}

#Preview {
    ErrorView(message: "Could not connect to Homebrew.")
}

#Preview("With Retry") {
    ErrorView(message: "Failed to load formulae.") {
        print("Retrying...")
    }
}

#Preview("Brew Not Found") {
    ErrorView(message: "Homebrew not found. Please install Homebrew first.")
}

#Preview("Permission Denied") {
    ErrorView(message: "Brew command failed (exit 1): permission denied")
}

#Preview("Timeout") {
    ErrorView(message: "Brew command timed out.")
}

#Preview("Custom Suggestion") {
    ErrorView(
        message: "Something unexpected happened.",
        suggestion: "Try restarting the application."
    )
}
