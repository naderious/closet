import Foundation

/// How a color behaves in an outfit.
enum ColorRole: Equatable {
    /// Black, white, greys and other near-achromatic colors.
    case neutral
    /// Beige, tan, camel, brown, khaki, olive: warm neutrals.
    case earth
    /// Deep navy works as a neutral.
    case navy
    /// Blue denim pairs with almost anything.
    case denim
    /// Everything with enough color to be noticed.
    case accent
}

struct ColorProfile {
    let color: RGBColor
    let lch: OKLCH
    let hue: Double
    let role: ColorRole

    init(_ color: RGBColor, category: ClothingCategory? = nil) {
        self.color = color
        let lch = color.oklch
        self.lch = lch
        self.hue = color.artisticHue
        self.role = ColorProfile.role(for: lch, category: category)
    }

    var isNeutralLike: Bool { role != .accent }

    var isBlackish: Bool { lch.l < 0.32 && lch.c < 0.045 }

    var isBrownish: Bool { role == .earth && lch.l < 0.58 }

    static func role(for lch: OKLCH, category: ClothingCategory?) -> ColorRole {
        if lch.c < 0.035 { return .neutral }
        if category == .jeans, (200...290).contains(lch.h), lch.c < 0.17 { return .denim }
        if (35...125).contains(lch.h), lch.c < 0.10, (0.2...0.93).contains(lch.l) { return .earth }
        if (230...285).contains(lch.h), lch.l < 0.40, lch.c < 0.16 { return .navy }
        return .accent
    }
}

enum HarmonyScheme: String {
    case tonal, neutral, accent, monochrome, analogous, complementary, triadic, discordant, busy
}

enum ColorHarmony {
    /// Scores how well a set of garment colors work together (0...1) and names the scheme.
    static func evaluate(_ profiles: [ColorProfile]) -> (score: Double, scheme: HarmonyScheme) {
        guard !profiles.isEmpty else { return (0.8, .neutral) }
        let accents = profiles.filter { $0.role == .accent }

        switch accents.count {
        case 0:
            let lightness = profiles.map(\.lch.l)
            let spread = (lightness.max() ?? 0) - (lightness.min() ?? 0)
            if profiles.allSatisfy(\.isBlackish) { return (0.87, .tonal) }
            if spread < 0.12 { return (0.85, .tonal) }
            return (0.83, .neutral)

        case 1:
            // One pop of color against neutrals is the safest strong look.
            let accent = accents[0]
            let score = accent.lch.c > 0.22 ? 0.86 : 0.9
            return (score, .accent)

        case 2:
            return evaluatePair(accents[0], accents[1])

        default:
            let hues = accents.map(\.hue)
            let span = arcSpan(of: hues)
            if span <= 70 { return (0.78, .analogous) }
            if isTriad(hues) { return (0.64, .triadic) }
            let muted = accents.filter { $0.lch.c < 0.08 }.count
            return (muted >= accents.count - 1 ? 0.55 : 0.34, .busy)
        }
    }

    private static func evaluatePair(_ a: ColorProfile, _ b: ColorProfile) -> (Double, HarmonyScheme) {
        let distance = Angles.distance(a.hue, b.hue)
        let lightnessGap = abs(a.lch.l - b.lch.l)
        let bothMuted = a.lch.c < 0.09 && b.lch.c < 0.09
        let bothLoud = a.lch.c > 0.14 && b.lch.c > 0.14

        switch distance {
        case ..<20:
            return (lightnessGap > 0.1 ? 0.9 : 0.84, .monochrome)
        case ..<50:
            return (0.85, .analogous)
        case ..<100:
            return (bothMuted ? 0.62 : 0.42, .discordant)
        case ..<145:
            return (bothLoud ? 0.56 : 0.66, .triadic)
        default:
            if bothLoud && lightnessGap < 0.12 { return (0.6, .complementary) }
            return (0.8, .complementary)
        }
    }

    /// The smallest arc of the wheel that contains every hue.
    static func arcSpan(of hues: [Double]) -> Double {
        guard hues.count > 1 else { return 0 }
        let sorted = hues.map { ($0.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) }.sorted()
        var largestGap = 0.0
        for index in 0..<sorted.count {
            let next = index + 1 < sorted.count ? sorted[index + 1] : sorted[0] + 360
            largestGap = max(largestGap, next - sorted[index])
        }
        return 360 - largestGap
    }

    private static func isTriad(_ hues: [Double]) -> Bool {
        guard hues.count == 3 else { return false }
        let pairs = [(0, 1), (1, 2), (0, 2)]
        return pairs.allSatisfy { pair in
            (95...145).contains(Angles.distance(hues[pair.0], hues[pair.1]))
        }
    }
}
