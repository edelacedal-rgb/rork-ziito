import SwiftUI

/// Centralized design tokens that mirror the Ziito web app exactly
/// (mint canvas, white bordered cards, forest-green primary, amber accent).
extension Color {
    /// App canvas — soft mint, `hsl(160 30% 98%)`.
    static let zBackground = Color(hex: "F7FBF9") ?? .white
    /// White cards.
    static let zCardBG = Color.white
    /// Subtle card border, `hsl(214 32% 91%)`.
    static let zBorder = Color(hex: "E2E8F0") ?? Color.gray.opacity(0.2)
    /// Light green chip / segmented background, `hsl(158 30% 92%)`.
    static let zSecondaryBG = Color(hex: "E4F0EB") ?? Color.gray.opacity(0.12)
    /// Muted text, `hsl(170 12% 42%)`.
    static let zMuted = Color(hex: "5E7873") ?? .secondary
    /// Primary text, `hsl(170 35% 12%)`.
    static let zForeground = Color(hex: "142926") ?? .primary
}

extension ShapeStyle where Self == Color {
    static var zBackground: Color { Color.zBackground }
    static var zMuted: Color { Color.zMuted }
    static var zForeground: Color { Color.zForeground }
    static var zSecondaryBG: Color { Color.zSecondaryBG }
    static var zBorder: Color { Color.zBorder }
}

/// White card with a 1pt border and rounded corners, matching the web `bg-card border` look.
struct ZCard: ViewModifier {
    var radius: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .background(Color.zCardBG, in: .rect(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.zBorder, lineWidth: 1)
            )
    }
}

extension View {
    func zCard(radius: CGFloat = 16) -> some View { modifier(ZCard(radius: radius)) }
}

/// Large inline screen header used across the app (matches the web's extrabold titles).
struct ZScreenHeader: View {
    let title: String
    var onBack: (() -> Void)? = nil
    var onAdd: (() -> Void)? = nil
    /// Optional trailing pill (e.g. the "Plan" button on Hoy).
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let onBack {
                Button {
                    Haptics.tap(.light)
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.zForeground)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
            Text(title)
                .font(.system(size: 28, weight: .heavy))
                .foregroundStyle(.zForeground)
            Spacer()
            if let trailing {
                trailing
            }
            if let onAdd {
                Button {
                    Haptics.tap(.light)
                    onAdd()
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.zPrimary, in: .circle)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }
}

/// Pill priority badge identical to the web `PriorityBadge`.
struct ZPriorityBadge: View {
    let priority: PriorityLevel
    var body: some View {
        let c = Color(hex: priority.colorName) ?? .gray
        Text(priority.shortLabel)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(c)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(c.opacity(0.12), in: .capsule)
    }
}

/// Shared Spanish date helpers mirroring `ziito-date.ts`.
enum ZDate {
    static func greeting() -> String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Buenos días"
        case 12..<18: return "Buenas tardes"
        default: return "Buenas noches"
        }
    }

    static func longDate(_ d: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "EEEE, d 'de' MMMM"
        return f.string(from: d).capitalized
    }

    static func shortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "d MMM"
        return f.string(from: d)
    }
}
