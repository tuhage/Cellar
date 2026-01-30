import SwiftUI
import CellarCore

struct StatCardView: View {
    let title: String
    let value: String
    let systemImage: String
    var color: Color = .accentColor

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())

                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        StatCardView(title: "Formulae", value: "142", systemImage: "terminal", color: .blue)
        StatCardView(title: "Casks", value: "38", systemImage: "macwindow", color: .purple)
        StatCardView(title: "Services", value: "4/7", systemImage: "gearshape.2", color: .green)
        StatCardView(title: "Updates", value: "5", systemImage: "arrow.triangle.2.circlepath", color: .orange)
    }
    .padding()
    .frame(width: 500)
}
