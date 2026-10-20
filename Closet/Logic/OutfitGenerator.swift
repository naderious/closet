import Foundation

/// Deterministic generator for tests and previews.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        // SplitMix64
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Builds outfits from the wardrobe: samples candidate combinations, scores them with
/// `OutfitScorer`, and picks one of the best so regenerating stays varied but good.
struct OutfitGenerator {
    var beltProbability = 0.75
    var outerProbability = 0.4
    var maxCandidates = 600
    /// Lower = always pick the top scorer; higher = more variety.
    var temperature = 0.045

    func generate<R: RandomNumberGenerator>(from items: [ClothingItem], history: [Outfit], using rng: inout R) -> Outfit? {
        guard !items.isEmpty else { return nil }
        let pools = Dictionary(grouping: items, by: { $0.category.slot })
        func has(_ slot: OutfitSlot) -> Bool { !(pools[slot]?.isEmpty ?? true) }

        var slots: [OutfitSlot] = []
        if has(.top) { slots.append(.top) }
        if has(.bottom) { slots.append(.bottom) }
        if has(.shoes) { slots.append(.shoes) }
        if has(.belt), has(.bottom) || slots.isEmpty, Double.random(in: 0..<1, using: &rng) < beltProbability || slots.isEmpty {
            slots.append(.belt)
        }
        if has(.outer), !has(.top) || Double.random(in: 0..<1, using: &rng) < outerProbability {
            slots.append(.outer)
        }
        guard !slots.isEmpty else { return nil }

        let recent = RecentUse(history: history)
        var candidates: [[OutfitSlot: ClothingItem]] = []
        let combinations = slots.reduce(1) { $0 * (pools[$1]?.count ?? 1) }

        if combinations <= maxCandidates {
            candidates = [[:]]
            for slot in slots {
                let pool = pools[slot] ?? []
                candidates = candidates.flatMap { partial in
                    pool.map { item in
                        var next = partial
                        next[slot] = item
                        return next
                    }
                }
            }
        } else {
            var seen = Set<[UUID?]>()
            for _ in 0..<maxCandidates {
                var candidate: [OutfitSlot: ClothingItem] = [:]
                for slot in slots {
                    let pool = pools[slot] ?? []
                    if let item = weightedPick(pool, weight: { recent.samplingWeight(for: $0) }, using: &rng) {
                        candidate[slot] = item
                    }
                }
                let key = slots.map { candidate[$0]?.id }
                if seen.insert(key).inserted { candidates.append(candidate) }
            }
        }

        return choose(from: candidates, recent: recent, using: &rng)
    }

    /// Swaps the piece in one slot for the best-fitting alternative, keeping the rest.
    func reroll<R: RandomNumberGenerator>(
        slot: OutfitSlot, in outfit: Outfit, items: [ClothingItem], history: [Outfit], using rng: inout R
    ) -> Outfit? {
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let alternatives = items.filter { $0.category.slot == slot && $0.id != outfit[slot] }
        guard !alternatives.isEmpty else { return nil }

        var base: [OutfitSlot: ClothingItem] = [:]
        for other in OutfitSlot.allCases where other != slot {
            if let id = outfit[other], let item = byID[id] { base[other] = item }
        }
        let candidates = alternatives.map { item -> [OutfitSlot: ClothingItem] in
            var candidate = base
            candidate[slot] = item
            return candidate
        }
        return choose(from: candidates, recent: RecentUse(history: history), using: &rng)
    }

    // MARK: Selection

    private func choose<R: RandomNumberGenerator>(
        from candidates: [[OutfitSlot: ClothingItem]], recent: RecentUse, using rng: inout R
    ) -> Outfit? {
        guard !candidates.isEmpty else { return nil }
        let cache = OutfitScorer.Cache()
        let scored = candidates
            .map { ($0, OutfitScorer.score($0, cache: cache).total - recent.penalty(for: $0)) }
            .sorted { $0.1 > $1.1 }
        let shortlist = Array(scored.prefix(max(1, min(12, scored.count / 4 + 1))))
        let best = shortlist[0].1
        let picked = weightedPick(shortlist, weight: { exp(($0.1 - best) / temperature) }, using: &rng) ?? shortlist[0]

        var outfit = Outfit()
        for (slot, item) in picked.0 { outfit[slot] = item.id }
        return outfit
    }

    private func weightedPick<T, R: RandomNumberGenerator>(_ values: [T], weight: (T) -> Double, using rng: inout R) -> T? {
        guard !values.isEmpty else { return nil }
        let weights = values.map { max(0, weight($0)) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return values.randomElement(using: &rng) }
        var target = Double.random(in: 0..<total, using: &rng)
        for (value, weight) in zip(values, weights) {
            if target < weight { return value }
            target -= weight
        }
        return values.last
    }
}

/// Remembers what was shown recently so the wardrobe gets rotated.
private struct RecentUse {
    let lastPieces: Set<UUID>
    let recentCounts: [UUID: Int]
    let recentSignatures: Set<[UUID?]>

    init(history: [Outfit]) {
        lastPieces = Set(history.last?.itemIDs ?? [])
        var counts: [UUID: Int] = [:]
        for outfit in history.suffix(4) {
            for id in outfit.itemIDs { counts[id, default: 0] += 1 }
        }
        recentCounts = counts
        recentSignatures = Set(history.suffix(8).map(\.signature))
    }

    func samplingWeight(for item: ClothingItem) -> Double {
        var weight = item.isFavorite ? 1.5 : 1
        if lastPieces.contains(item.id) { weight *= 0.35 }
        return weight
    }

    func penalty(for candidate: [OutfitSlot: ClothingItem]) -> Double {
        let signature = OutfitSlot.allCases.map { candidate[$0]?.id }
        var penalty = recentSignatures.contains(signature) ? 0.5 : 0
        for item in candidate.values {
            if lastPieces.contains(item.id) { penalty += 0.05 }
            penalty += Double(recentCounts[item.id] ?? 0) * 0.02
        }
        return penalty
    }
}
