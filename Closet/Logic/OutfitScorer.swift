import Foundation

/// Scores a candidate outfit using color theory and a few classic styling rules.
enum OutfitScorer {
    struct Breakdown {
        var harmony: Double
        var scheme: HarmonyScheme
        var contrast: Double
        var beltAndShoes: Double
        var proportion: Double
        var pairing: Double
        var favorites: Double

        var total: Double {
            harmony * 0.42
                + contrast * 0.15
                + beltAndShoes * 0.10
                + proportion * 0.12
                + pairing * 0.09
                + favorites * 0.12
        }
    }

    /// Memoizes per-item color analysis while many candidates are scored.
    final class Cache {
        private var profiles: [UUID: ColorProfile] = [:]
        private var descriptions: [UUID: Description] = [:]

        struct Description {
            /// Cut / fit text, lowercased.
            var shape: String
            /// Material text, lowercased.
            var material: String
            var volume: Double?
            var shoeStyle: ShoeStyle
        }

        func profile(for item: ClothingItem) -> ColorProfile {
            if let cached = profiles[item.id] { return cached }
            let profile = ColorProfile(item.color, category: item.category)
            profiles[item.id] = profile
            return profile
        }

        func description(for item: ClothingItem) -> Description {
            if let cached = descriptions[item.id] { return cached }
            let shape = (item.secondaryAttribute + " " + item.name).lowercased()
            let description = Description(
                shape: shape,
                material: (item.primaryAttribute + " " + item.name).lowercased(),
                volume: OutfitScorer.volume(of: shape),
                shoeStyle: OutfitScorer.shoeStyle(of: shape)
            )
            descriptions[item.id] = description
            return description
        }
    }

    static func score(_ pieces: [OutfitSlot: ClothingItem], cache: Cache = Cache()) -> Breakdown {
        let profiles = pieces.mapValues { cache.profile(for: $0) }
        let harmony = ColorHarmony.evaluate(Array(profiles.values))
        let favoriteShare = pieces.isEmpty ? 0 : Double(pieces.values.filter(\.isFavorite).count) / Double(pieces.count)

        return Breakdown(
            harmony: harmony.score,
            scheme: harmony.scheme,
            contrast: contrastScore(top: profiles[.top], bottom: profiles[.bottom], outer: profiles[.outer]),
            beltAndShoes: beltShoeScore(belt: profiles[.belt], shoes: profiles[.shoes]),
            proportion: proportionScore(top: pieces[.top], bottom: pieces[.bottom], outer: pieces[.outer], cache: cache),
            pairing: pairingScore(pieces, profiles: profiles, cache: cache),
            favorites: favoriteShare
        )
    }

    // MARK: Light/dark balance

    static func contrastScore(top: ColorProfile?, bottom: ColorProfile?, outer: ColorProfile?) -> Double {
        guard let top, let bottom else { return 0.8 }
        var score = layerContrast(top, bottom)
        if let outer {
            score = (score * 2 + layerContrast(outer, top)) / 3
        }
        return score
    }

    private static func layerContrast(_ a: ColorProfile, _ b: ColorProfile) -> Double {
        let gap = abs(a.lch.l - b.lch.l)
        if gap >= 0.22 { return 1 }
        if gap < 0.07 {
            // Deliberate tonal dressing reads well; an accidental near-match does not.
            return sameFamily(a, b) ? 0.88 : 0.55
        }
        return 0.6 + (gap - 0.07) / 0.15 * 0.4
    }

    private static func sameFamily(_ a: ColorProfile, _ b: ColorProfile) -> Bool {
        if a.isNeutralLike && b.isNeutralLike { return a.color.distance(to: b.color) < 0.09 }
        if a.role == .accent && b.role == .accent { return Angles.distance(a.hue, b.hue) <= 20 }
        return false
    }

    // MARK: Leathers should match

    static func beltShoeScore(belt: ColorProfile?, shoes: ColorProfile?) -> Double {
        guard let belt, let shoes else { return 0.75 }
        let distance = belt.color.distance(to: shoes.color)
        if distance < 0.06 { return 1 }
        if distance < 0.12 { return 0.85 }
        if (belt.isBlackish && shoes.isBrownish) || (shoes.isBlackish && belt.isBrownish) { return 0.15 }
        return 0.55
    }

    // MARK: Silhouette

    /// -1 (slim/fitted) … +1 (loose/wide), or nil when the description says nothing about volume.
    static func volume(of description: String) -> Double? {
        let text = description.lowercased()
        let weights: [(String, Double)] = [
            ("loose", 1), ("wide", 1), ("baggy", 1), ("oversized", 1), ("balloon", 1), ("puddle", 0.8),
            ("boxy", 0.8), ("flare", 0.7), ("relaxed", 0.6), ("bootcut", 0.5), ("boot cut", 0.5), ("longline", 0.3),
            ("skinny", -1), ("tight", -1), ("slim", -0.8), ("fitted", -0.8), ("muscle", -0.8),
            ("tapered", -0.5), ("cropped", -0.4), ("straight", 0), ("regular", 0), ("classic", 0),
        ]
        var total = 0.0
        var matched = false
        for (keyword, weight) in weights where text.contains(keyword) {
            total += weight
            matched = true
        }
        guard matched else { return nil }
        if text.contains("slight") || text.contains("subtle") { total *= 0.5 }
        if text.contains("very") || text.contains("super") || text.contains("extra") { total *= 1.3 }
        return total.clamped(to: -1...1)
    }

    static func proportionScore(top: ClothingItem?, bottom: ClothingItem?, outer: ClothingItem?, cache: Cache) -> Double {
        let topVolume = top.flatMap { cache.description(for: $0).volume }
        let bottomVolume = bottom.flatMap { cache.description(for: $0).volume }
        if topVolume == nil && bottomVolume == nil { return 0.8 }
        let t = topVolume ?? 0
        let b = bottomVolume ?? 0
        var score: Double
        if t > 0.5 && b > 0.5 {
            score = 0.45
        } else if (t < -0.3 && b > 0.3) || (t > 0.3 && b < -0.3) {
            score = 1
        } else if t < -0.3 && b < -0.3 {
            score = 0.75
        } else {
            score = 0.85
        }
        // An oversized jacket over an oversized top and loose trousers is a lot of fabric.
        if let outer, let outerVolume = cache.description(for: outer).volume, outerVolume > 0.5, t > 0.5 {
            score -= 0.15
        }
        return score.clamped(to: 0...1)
    }

    // MARK: Shoes vs. cut, and texture clashes

    enum ShoeStyle { case boots, sneakers, loafers, dress, sandals, unknown }

    static func shoeStyle(of text: String) -> ShoeStyle {
        if text.contains("boot") || text.contains("chelsea") || text.contains("wyatt") { return .boots }
        if text.contains("sneaker") || text.contains("trainer") || text.contains("runner") { return .sneakers }
        if text.contains("loafer") || text.contains("mule") { return .loafers }
        if text.contains("derby") || text.contains("derbies") || text.contains("oxford") || text.contains("brogue") { return .dress }
        if text.contains("sandal") || text.contains("slide") { return .sandals }
        return .unknown
    }

    static func pairingScore(_ pieces: [OutfitSlot: ClothingItem], profiles: [OutfitSlot: ColorProfile], cache: Cache) -> Double {
        var scores: [Double] = []

        if let shoes = pieces[.shoes], let bottom = pieces[.bottom] {
            let cut = cache.description(for: bottom).shape
            let style = cache.description(for: shoes).shoeStyle
            if cut.contains("boot") || cut.contains("flare") {
                scores.append(style == .boots ? 1 : (style == .sandals ? 0.5 : 0.62))
            } else if cut.contains("wide") || cut.contains("baggy") || cut.contains("loose") {
                scores.append(lookup([.sneakers: 0.95, .boots: 0.8, .loafers: 0.78, .dress: 0.7], style, fallback: 0.75))
            } else if cut.contains("skinny") || cut.contains("slim") {
                scores.append(lookup([.boots: 0.95, .sneakers: 0.85, .loafers: 0.85], style, fallback: 0.72))
            } else if cut.contains("straight") {
                scores.append(lookup([.loafers: 0.95, .dress: 0.95, .boots: 0.88, .sneakers: 0.85], style, fallback: 0.75))
            }
        }

        if let outer = pieces[.outer], let bottom = pieces[.bottom] {
            let outerMaterial = cache.description(for: outer).material
            let bottomMaterial = cache.description(for: bottom).material
            if outerMaterial.contains("denim") && bottom.category == .jeans {
                // Double denim works when the washes are clearly different.
                let gap = abs((profiles[.outer]?.lch.l ?? 0) - (profiles[.bottom]?.lch.l ?? 0))
                scores.append(gap > 0.15 ? 0.75 : 0.35)
            }
            if outerMaterial.contains("leather") && bottomMaterial.contains("leather") {
                scores.append(0.5)
            }
        }

        guard !scores.isEmpty else { return 0.8 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    private static func lookup(_ table: [ShoeStyle: Double], _ style: ShoeStyle, fallback: Double) -> Double {
        table[style] ?? fallback
    }
}
