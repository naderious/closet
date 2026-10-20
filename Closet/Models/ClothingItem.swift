import Foundation

struct ClothingItem: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var category: ClothingCategory
    var colorHex: String
    var primaryAttribute: String
    var secondaryAttribute: String
    var isFavorite: Bool
    var imageFileName: String
    /// Width / height of the background-removed image.
    var imageAspect: Double
    var edgeProfile: EdgeProfile?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: ClothingCategory,
        colorHex: String,
        primaryAttribute: String = "",
        secondaryAttribute: String = "",
        isFavorite: Bool = false,
        imageFileName: String = "",
        imageAspect: Double = 1,
        edgeProfile: EdgeProfile? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.colorHex = colorHex
        self.primaryAttribute = primaryAttribute
        self.secondaryAttribute = secondaryAttribute
        self.isFavorite = isFavorite
        self.imageFileName = imageFileName
        self.imageAspect = imageAspect
        self.edgeProfile = edgeProfile
        self.createdAt = createdAt
    }

    var color: RGBColor {
        RGBColor(hex: colorHex) ?? RGBColor(white: 0.5)
    }

    /// The name to show; falls back to something descriptive like "black jeans".
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "\(ColorNaming.name(for: color)) \(category.singular)" : trimmed
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, category, colorHex, primaryAttribute, secondaryAttribute
        case isFavorite, imageFileName, imageAspect, edgeProfile, createdAt
    }

    // Lenient decoding so older or partially written files still load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        let rawCategory = try container.decodeIfPresent(String.self, forKey: .category) ?? ""
        category = ClothingCategory(rawValue: rawCategory) ?? .shirts
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "#808080"
        primaryAttribute = try container.decodeIfPresent(String.self, forKey: .primaryAttribute) ?? ""
        secondaryAttribute = try container.decodeIfPresent(String.self, forKey: .secondaryAttribute) ?? ""
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName) ?? ""
        imageAspect = try container.decodeIfPresent(Double.self, forKey: .imageAspect) ?? 1
        edgeProfile = try container.decodeIfPresent(EdgeProfile.self, forKey: .edgeProfile)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}
