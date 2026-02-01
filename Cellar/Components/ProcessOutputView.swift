import SwiftUI
import CellarCore

struct ProcessOutputView: View {
    let title: String
    let stream: AsyncThrowingStream<String, Error>

    @State private var lines: [String] = []
    @State private var isRunning = true
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.5)
            outputArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await consumeStream() }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            if isRunning {
                ProgressView()
                    .controlSize(.small)
            } else if error != nil {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(AnimationToken.snap, value: isRunning)
        .padding(Spacing.cardPadding)
    }

    private var outputArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .id(index)
                    }

                    if let error {
                        Text(error)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.red)
                            .id("error")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(.primary.opacity(0.02))
            .background(.background.secondary)
            .onChange(of: lines.count) {
                withAnimation {
                    proxy.scrollTo(lines.count - 1, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Stream Consumption

    private func consumeStream() async {
        do {
            for try await line in stream {
                lines.append(line)
            }
        } catch {
            self.error = error.localizedDescription
        }
        isRunning = false
    }
}

#Preview {
    ProcessOutputView(
        title: "Installing wget",
        stream: AsyncThrowingStream { continuation in
            Task {
                let sampleLines = [
                    "==> Fetching wget",
                    "==> Downloading https://ghcr.io/v2/homebrew/core/wget/manifests/1.24.5",
                    "==> Installing wget",
                    "==> Pouring wget--1.24.5.arm64_sonoma.bottle.tar.gz",
                    "🍺  /opt/homebrew/Cellar/wget/1.24.5: 89 files, 4.2MB",
                ]
                for line in sampleLines {
                    try? await Task.sleep(for: .milliseconds(500))
                    continuation.yield(line)
                }
                continuation.finish()
            }
        }
    )
    .frame(width: 600, height: 400)
}
