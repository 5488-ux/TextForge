import SwiftUI

enum TextForgePalette {
    static let blue = Color(red: 0.10, green: 0.48, blue: 1.00)
    static let indigo = Color(red: 0.34, green: 0.24, blue: 0.92)
    static let cyan = Color(red: 0.08, green: 0.76, blue: 0.94)
    static let violet = Color(red: 0.68, green: 0.34, blue: 0.96)
}

struct TextForgeBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.95, green: 0.98, blue: 1.00)

            LinearGradient(
                colors: [
                    .white.opacity(0.96),
                    Color(red: 0.86, green: 0.93, blue: 1.00),
                    Color(red: 0.94, green: 0.89, blue: 1.00).opacity(0.78)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(TextForgePalette.cyan.opacity(0.19))
                .frame(width: 290, height: 290)
                .blur(radius: 30)
                .offset(x: 165, y: -310)

            Circle()
                .fill(TextForgePalette.violet.opacity(0.16))
                .frame(width: 330, height: 330)
                .blur(radius: 42)
                .offset(x: -175, y: 330)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct TextForgeLogo: View {
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [TextForgePalette.blue, TextForgePalette.indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: TextForgePalette.blue.opacity(0.28), radius: 15, y: 8)

            Image(systemName: "text.page.fill")
                .font(.system(size: size * 0.43, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

struct TextForgeSectionTitle: View {
    let title: String
    let subtitle: String
    var trailingText: String?

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title3.weight(.bold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let trailingText {
                Text(trailingText)
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(TextForgePalette.blue)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(TextForgePalette.blue.opacity(0.10), in: Capsule())
            }
        }
    }
}

extension View {
    func textForgeGlassCard(
        padding: CGFloat = 17,
        cornerRadius: CGFloat = 26
    ) -> some View {
        modifier(TextForgeGlassCardModifier(padding: padding, cornerRadius: cornerRadius))
    }

    func textForgeInput(cornerRadius: CGFloat = 16) -> some View {
        padding(13)
            .background(.white.opacity(0.70), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.92), lineWidth: 1)
            }
    }
}

private struct TextForgeGlassCardModifier: ViewModifier {
    let padding: CGFloat
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .padding(padding)
                .glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .padding(padding)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.95), .white.opacity(0.38)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: TextForgePalette.indigo.opacity(0.09), radius: 22, y: 12)
        }
    }
}

struct TextForgeCircleButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.primary.opacity(0.72))
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.60), in: Circle())
                .overlay { Circle().stroke(.white.opacity(0.92), lineWidth: 1) }
                .shadow(color: .black.opacity(0.06), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
