import SwiftUI
import CellarCore

struct StatCardView: View {
    let title: String
    let value: String
    let systemImage: String
    var color: Color = .accentColor

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.1), in: Circle())

            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .contentTransition(.numericText())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(color.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    HStack(spacing: 16) {
        StatCardView(title: "Formulae", value: "142", systemImage: "shippingbox", color: .blue)
        StatCardView(title: "Casks", value: "38", systemImage: "macwindow", color: .purple)
        StatCardView(title: "Outdated", value: "7", systemImage: "arrow.triangle.2.circlepath", color: .orange)
        StatCardView(title: "Services", value: "4", systemImage: "gear", color: .green)
    }
    .padding()
    .frame(width: 600)
}
