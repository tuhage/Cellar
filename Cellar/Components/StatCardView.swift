import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let systemImage: String
    var color: Color = .accentColor

    var body: some View {
        GroupBox {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.title)
                    .foregroundStyle(color)

                Text(value)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
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
