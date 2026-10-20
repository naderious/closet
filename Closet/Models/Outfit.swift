import Foundation

struct Outfit: Codable, Equatable, Identifiable {
    var id = UUID()
    var outer: UUID?
    var top: UUID?
    var bottom: UUID?
    var belt: UUID?
    var shoes: UUID?

    subscript(slot: OutfitSlot) -> UUID? {
        get {
            switch slot {
            case .outer: return outer
            case .top: return top
            case .bottom: return bottom
            case .belt: return belt
            case .shoes: return shoes
            }
        }
        set {
            switch slot {
            case .outer: outer = newValue
            case .top: top = newValue
            case .bottom: bottom = newValue
            case .belt: belt = newValue
            case .shoes: shoes = newValue
            }
        }
    }

    var itemIDs: [UUID] {
        OutfitSlot.allCases.compactMap { self[$0] }
    }

    var isEmpty: Bool { itemIDs.isEmpty }

    /// Identifies the combination of pieces regardless of the outfit's own id.
    var signature: [UUID?] {
        OutfitSlot.allCases.map { self[$0] }
    }

    /// Drops pieces that no longer exist in the wardrobe.
    func pruned(keeping ids: Set<UUID>) -> Outfit {
        var copy = self
        for slot in OutfitSlot.allCases where copy[slot].map({ !ids.contains($0) }) ?? false {
            copy[slot] = nil
        }
        return copy
    }
}
