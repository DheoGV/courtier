import SwiftUI

// Design tokens mirrored from design/padel-score.pen, theme "Courtier — Elegan" (style axis = elegant).

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension ShapeStyle where Self == Color {
    // Surfaces
    static var appBackground: Color { Color(hex: 0xF6F1E9) }   // ivory
    static var surface: Color { .white }
    static var surface2: Color { Color(hex: 0xEFE7DA) }
    static var line: Color { Color(hex: 0xDCCFBC) }

    // Text
    static var ink: Color { Color(hex: 0x1F2A24) }
    static var inkMuted: Color { Color(hex: 0x7A7266) }

    // Brand
    static var racing: Color { Color(hex: 0x1F3B2E) }          // primary / hero
    static var onRacing: Color { Color(hex: 0xF6F1E9) }
    static var brass: Color { Color(hex: 0xB08D57) }           // accent
    static var brassInk: Color { Color(hex: 0x9A7643) }        // accent used as text / icons
    static var heroAccent: Color { Color(hex: 0xD2B37A) }
    static var heroMuted: Color { Color(hex: 0xA9B8AE) }

    // Status
    static var win: Color { Color(hex: 0x2F6B4F) }
    static var loss: Color { Color(hex: 0x9B3D2E) }
    static var glow: Color { Color(hex: 0x1F2A24, opacity: 0.07) }
}

enum Radius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 10
    static let lg: CGFloat = 18
}

enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    /// Screen side gutter.
    static let gutter: CGFloat = 20
}
