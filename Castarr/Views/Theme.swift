//
//  Theme.swift
//  RoleCall
//
//  Created by Codex on 3/8/24.
//

import SwiftUI

enum Theme {
    enum Colors {
        static let background = Color(hex: "#0E1117")
        static let surface = Color(hex: "#1A1F24")
        static let primaryAccent = Color(hex: "#E5A00D")
        static let secondaryAccent = Color(hex: "#00BFA6")
        static let highlight = Color(hex: "#A0A0A0")
        static let text = Color(hex: "#EDEDED")
        static let error = Color.red
    }

    enum Typography {
        static let title = Font.system(.largeTitle, design: .default).weight(.bold)
        static let subtitle = Font.system(.title2, design: .default).weight(.semibold)
        static let body = Font.system(.body, design: .default)
        static let caption = Font.system(.caption, design: .default)
    }

    struct PrimaryButtonStyle: ButtonStyle {
        @Environment(\.isEnabled) private var isEnabled

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isEnabled ? Colors.primaryAccent : Colors.primaryAccent.opacity(0.4))
                )
                .foregroundColor(Colors.background)
                .opacity(configuration.isPressed ? 0.9 : 1.0)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
        }
    }

    struct SecondaryButtonStyle: ButtonStyle {
        @Environment(\.isEnabled) private var isEnabled

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Colors.surface.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Colors.secondaryAccent.opacity(isEnabled ? 0.8 : 0.4), lineWidth: 1)
                        )
                )
                .foregroundColor(isEnabled ? Colors.secondaryAccent : Colors.secondaryAccent.opacity(0.6))
                .opacity(configuration.isPressed ? 0.9 : 1.0)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
        }
    }

    struct CardBackground: ViewModifier {
        var cornerRadius: CGFloat = 16
        var padding: CGFloat = 16

        func body(content: Content) -> some View {
            content
                .padding(padding)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Colors.surface.opacity(0.94))
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(Colors.highlight.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: Colors.background.opacity(0.4), radius: 12, x: 0, y: 8)
                )
        }
    }

    struct TagStyle: ViewModifier {
        let accent: Color

        func body(content: Content) -> some View {
            content
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(accent.opacity(0.18))
                .foregroundColor(accent)
                .clipShape(Capsule())
        }
    }
}

extension View {
    func themeCard(cornerRadius: CGFloat = 16, padding: CGFloat = 16) -> some View {
        modifier(Theme.CardBackground(cornerRadius: cornerRadius, padding: padding))
    }

    func themeTag(accent: Color = Theme.Colors.secondaryAccent) -> some View {
        modifier(Theme.TagStyle(accent: accent))
    }
}

extension Color {
    init(hex: String) {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&int)

        let r, g, b, a: UInt64
        switch trimmed.count {
        case 3: // RGB (12-bit)
            (r, g, b, a) = (
                (int >> 8) * 17,
                (int >> 4 & 0xF) * 17,
                (int & 0xF) * 17,
                255
            )
        case 6: // RGB (24-bit)
            (r, g, b, a) = (
                int >> 16 & 0xFF,
                int >> 8 & 0xFF,
                int & 0xFF,
                255
            )
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (
                int >> 24 & 0xFF,
                int >> 16 & 0xFF,
                int >> 8 & 0xFF,
                int & 0xFF
            )
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
