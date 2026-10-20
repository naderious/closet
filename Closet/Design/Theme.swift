import SwiftUI

enum Theme {
    static let background = Color(white: 0.012)
    static let text = Color.white
    static let secondaryText = Color.white.opacity(0.55)
    static let tertiaryText = Color.white.opacity(0.32)
    static let line: CGFloat = 1.4
    static let gutter: CGFloat = 24
    static let cardRadius: CGFloat = 26
    static let rowRadius: CGFloat = 24
}

extension Color {
    init(_ color: RGBColor) {
        self.init(red: color.r, green: color.g, blue: color.b)
    }

    init(hex: String) {
        self.init(RGBColor(hex: hex) ?? RGBColor(white: 0.5))
    }
}

/// Each wardrobe section gets its own quiet color so neighboring cards always contrast.
struct SectionStyle {
    let card: Color
    let row: Color
    let glow: Color

    static let favorites = SectionStyle(card: Color(hex: "#262119"), row: Color(hex: "#302A1F"), glow: Color(hex: "#2A2010"))
}

extension ClothingCategory {
    var style: SectionStyle {
        switch self {
        case .shirts: return SectionStyle(card: Color(hex: "#0F120E"), row: Color(hex: "#1A211B"), glow: Color(hex: "#0D2414"))
        case .jackets: return SectionStyle(card: Color(hex: "#1F1B1A"), row: Color(hex: "#2B221F"), glow: Color(hex: "#2A1612"))
        case .sweaters: return SectionStyle(card: Color(hex: "#23242A"), row: Color(hex: "#2B2C35"), glow: Color(hex: "#10222C"))
        case .jeans: return SectionStyle(card: Color(hex: "#2C2430"), row: Color(hex: "#33212A"), glow: Color(hex: "#24132E"))
        case .pants: return SectionStyle(card: Color(hex: "#18211F"), row: Color(hex: "#1F2B29"), glow: Color(hex: "#0C2620"))
        case .belts: return SectionStyle(card: Color(hex: "#261D19"), row: Color(hex: "#30241F"), glow: Color(hex: "#2C170C"))
        case .shoes: return SectionStyle(card: Color(hex: "#1B1E2A"), row: Color(hex: "#232739"), glow: Color(hex: "#111A33"))
        }
    }
}

enum Motion {
    /// Page slides.
    static let page = Animation.spring(response: 0.58, dampingFraction: 0.9)
    /// Small UI responses.
    static let snappy = Animation.spring(response: 0.38, dampingFraction: 0.78)
    /// Garments settling onto the canvas.
    static let settle = Animation.spring(response: 0.62, dampingFraction: 0.78)
    static let gentle = Animation.easeInOut(duration: 0.45)
}

extension Edge {
    var opposite: Edge {
        switch self {
        case .leading: return .trailing
        case .trailing: return .leading
        case .top: return .bottom
        case .bottom: return .top
        }
    }
}
