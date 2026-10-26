import SwiftUI
import UIKit

extension Font {
    /// OpenType "wght" variation axis tag.
    private static let weightAxis = 0x7767_6874

    /// Bundled font when present, otherwise the system font of the same weight and design.
    /// Playfair Display and Jost ship as variable fonts, so the weight is set on their "wght" axis.
    private static func named(_ name: String, _ size: CGFloat, _ weight: Font.Weight, variable: Bool,
                              liningFigures: Bool = false, fallback: Font.Design) -> Font {
        guard let base = UIFont(name: name, size: size) else {
            return .system(size: size, weight: weight, design: fallback)
        }
        var attributes: [UIFontDescriptor.AttributeName: Any] = [:]
        if variable {
            attributes[UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)] = [weightAxis: axisValue(weight)]
        }
        if liningFigures {
            attributes[.featureSettings] = [[
                UIFontDescriptor.FeatureKey(rawValue: kCTFontOpenTypeFeatureTag as String): "lnum",
                UIFontDescriptor.FeatureKey(rawValue: kCTFontOpenTypeFeatureValue as String): 1,
            ]]
        }
        return Font(UIFont(descriptor: base.fontDescriptor.addingAttributes(attributes), size: size) as CTFont)
    }

    private static func axisValue(_ weight: Font.Weight) -> Int {
        switch weight {
        case .ultraLight: 200
        case .thin: 100
        case .light: 300
        case .medium: 500
        case .semibold: 600
        case .bold: 700
        case .heavy: 800
        case .black: 900
        default: 400
        }
    }

    /// Playfair Display — titles and score numerals. Falls back to New York.
    /// Lining figures: Playfair's default old-style digits drop below the baseline ("3", "9"), which looks off on a scoreboard.
    static func playfair(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        named("PlayfairDisplay-Regular", size, weight, variable: true, liningFigures: true, fallback: .serif)
    }

    /// Jost — UI text. Falls back to SF Pro.
    static func jost(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        named("Jost-Regular", size, weight, variable: true, fallback: .default)
    }

    /// Marcellus — the COURTIER wordmark only.
    static func marcellus(_ size: CGFloat) -> Font {
        named("Marcellus-Regular", size, .regular, variable: false, fallback: .serif)
    }

    // Type scale from the design system board.
    static let screenTitle = playfair(32, .semibold)
    static let sectionTitle = jost(17, .semibold)
    static let body = jost(15)
    static let bodyMedium = jost(15, .medium)
    static let caption = jost(12)
    static let eyebrow = jost(11, .semibold)
}
