//
//  Color+Extensions.swift
//  Resona
//
//  Created by Yizheng Jiang on 2/24/26.
//

import SwiftUI

extension Color {
    // Emotion palette colors
    static let coral = Color(red: 1.0, green: 0.42, blue: 0.42)
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.42)
    static let deepIndigo = Color(red: 0.39, green: 0.40, blue: 0.95)
    static let teal = Color(red: 0.08, green: 0.72, blue: 0.65)

    /// Linear interpolation between two colors
    static func lerp(from: Color, to: Color, t: CGFloat) -> Color {
        let t = min(max(t, 0), 1)
        let fromComponents = from.resolve(in: .init())
        let toComponents = to.resolve(in: .init())

        return Color(
            red: Double(fromComponents.red + (toComponents.red - fromComponents.red) * Float(t)),
            green: Double(fromComponents.green + (toComponents.green - fromComponents.green) * Float(t)),
            blue: Double(fromComponents.blue + (toComponents.blue - fromComponents.blue) * Float(t))
        )
    }

    /// Convert Color to hex string
    var hexString: String {
        let resolved = self.resolve(in: .init())
        let r = Int(resolved.red * 255)
        let g = Int(resolved.green * 255)
        let b = Int(resolved.blue * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// Initialize from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}
