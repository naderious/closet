import Foundation

/// Where a piece sits when an outfit is assembled.
enum OutfitSlot: String, Codable, CaseIterable {
    case outer, top, bottom, belt, shoes
}

/// A describable attribute of a category (e.g. the stitching of a pair of jeans),
/// with quick-pick suggestions shown while scanning.
struct AttributeField: Equatable {
    let label: String
    let suggestions: [String]
}

enum ClothingCategory: String, Codable, CaseIterable, Identifiable {
    case shirts, jackets, sweaters, jeans, pants, belts, shoes

    var id: String { rawValue }

    var title: String { rawValue }

    var singular: String {
        switch self {
        case .shirts: return "shirt"
        case .jackets: return "jacket"
        case .sweaters: return "sweater"
        case .jeans: return "jeans"
        case .pants: return "pants"
        case .belts: return "belt"
        case .shoes: return "shoes"
        }
    }

    var slot: OutfitSlot {
        switch self {
        case .shirts, .sweaters: return .top
        case .jackets: return .outer
        case .jeans, .pants: return .bottom
        case .belts: return .belt
        case .shoes: return .shoes
        }
    }

    /// Shown on the first attribute line of a wardrobe row (regular weight).
    var primaryField: AttributeField {
        switch self {
        case .shirts:
            return AttributeField(label: "fabric", suggestions: ["cotton jersey", "heavyweight cotton", "oxford", "flannel", "linen", "silk", "mesh"])
        case .jackets:
            return AttributeField(label: "material", suggestions: ["leather", "denim", "wool", "suede", "nylon", "waxed cotton", "shearling"])
        case .sweaters:
            return AttributeField(label: "knit", suggestions: ["cashmere", "merino", "mohair", "cotton", "cable knit", "waffle"])
        case .jeans:
            return AttributeField(label: "stitching", suggestions: ["selvedge", "bias tape", "normal"])
        case .pants:
            return AttributeField(label: "fabric", suggestions: ["wool", "cotton twill", "corduroy", "leather", "nylon", "linen"])
        case .belts:
            return AttributeField(label: "material", suggestions: ["leather", "suede", "snakeskin", "canvas", "chain"])
        case .shoes:
            return AttributeField(label: "material", suggestions: ["leather", "suede", "snakeskin", "canvas", "patent", "croc"])
        }
    }

    /// Shown on the second attribute line of a wardrobe row (bold).
    var secondaryField: AttributeField {
        switch self {
        case .shirts:
            return AttributeField(label: "fit", suggestions: ["fitted", "regular", "boxy", "oversized", "cropped", "slim"])
        case .jackets:
            return AttributeField(label: "fit", suggestions: ["cropped", "regular", "boxy", "oversized", "slim", "longline"])
        case .sweaters:
            return AttributeField(label: "fit", suggestions: ["fitted", "regular", "boxy", "oversized", "cropped"])
        case .jeans:
            return AttributeField(label: "cut", suggestions: ["bootcut", "loose bootcut", "slight bootcut", "flare", "straight", "slim", "skinny", "wide", "baggy"])
        case .pants:
            return AttributeField(label: "cut", suggestions: ["straight", "wide", "slim", "tapered", "flare", "pleated", "baggy"])
        case .belts:
            return AttributeField(label: "hardware", suggestions: ["silver", "gold", "gunmetal", "brass", "black"])
        case .shoes:
            return AttributeField(label: "style", suggestions: ["boots", "sneakers", "loafers", "derbies", "sandals", "mules"])
        }
    }
}
