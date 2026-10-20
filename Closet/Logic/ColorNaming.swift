import Foundation

/// Gives colors the names people actually use for clothes ("off-white", "navy", "camel"…).
enum ColorNaming {
    private static let palette: [(name: String, lab: OKLab)] = [
        ("black", "#0E0E0E"), ("charcoal", "#38383B"), ("grey", "#8A8A8A"), ("light grey", "#C9C9C9"),
        ("white", "#F7F7F5"), ("off-white", "#ECE7DA"), ("cream", "#F0E3C4"), ("beige", "#D6C19E"),
        ("tan", "#C19A6B"), ("camel", "#B5844A"), ("brown", "#6B4528"), ("chocolate", "#3D2A1E"),
        ("khaki", "#B7AC7F"), ("olive", "#6B6B35"), ("army green", "#4B5320"), ("forest green", "#24452F"),
        ("sage", "#9CAF88"), ("green", "#3A9A4A"), ("mint", "#A8DCC0"), ("teal", "#1F6F6F"),
        ("navy", "#1D2440"), ("indigo", "#2E3B5E"), ("denim", "#4A6587"), ("light wash", "#8BA5C1"),
        ("blue", "#2F5FBF"), ("sky blue", "#8EC5EA"), ("purple", "#5B3A8C"), ("lavender", "#B8A6D9"),
        ("burgundy", "#5E1A2B"), ("red", "#C0262D"), ("pink", "#E8A0B4"), ("rust", "#A4472A"),
        ("orange", "#E07A2E"), ("mustard", "#C9A227"), ("yellow", "#F0D43A"),
    ].compactMap { entry in
        RGBColor(hex: entry.1).map { (entry.0, $0.oklab) }
    }

    static func name(for color: RGBColor) -> String {
        let lab = color.oklab
        var best = "color"
        var bestDistance = Double.greatestFiniteMagnitude
        for entry in palette {
            let distance = entry.lab.distance(to: lab)
            if distance < bestDistance {
                bestDistance = distance
                best = entry.name
            }
        }
        return best
    }
}
