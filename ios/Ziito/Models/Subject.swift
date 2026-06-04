import Foundation
import SwiftData
import SwiftUI

@Model
final class Subject {
    var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date

    init(name: String, colorHex: String) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}

extension Color {
    /// Brand palette mirroring the Ziito web app.
    /// Forest green primary with an amber accent over a soft mint canvas.
    static let zPrimary = Color(red: 0.094, green: 0.427, blue: 0.306)      // #186D4E forest green
    static let zPrimaryBright = Color(red: 0.020, green: 0.588, blue: 0.412) // #059669 emerald-600
    static let zAccent = Color(red: 0.965, green: 0.659, blue: 0.137)        // #F6A823 amber
}

/// Lets the brand colors be used with the leading-dot syntax in
/// `foregroundStyle`, `tint`, `fill`, etc. (mirroring `.indigo`, `.accent`).
extension ShapeStyle where Self == Color {
    static var zPrimary: Color { Color.zPrimary }
    static var zPrimaryBright: Color { Color.zPrimaryBright }
    static var zAccent: Color { Color.zAccent }

    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String {
        let uic = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uic.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "%02lX%02lX%02lX",
            lroundf(Float(red) * 255),
            lroundf(Float(green) * 255),
            lroundf(Float(blue) * 255)
        )
    }
}

import UIKit
