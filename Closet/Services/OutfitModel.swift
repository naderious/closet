import Foundation
import Observation
import SwiftUI

/// Holds the outfit shown on the home screen and produces new ones.
@Observable
final class OutfitModel {
    private(set) var current: Outfit?
    private(set) var isGenerating = false
    /// Briefly true while the old outfit clears away before a new one arrives.
    private(set) var isClearing = false

    @ObservationIgnored private var history: [Outfit] = []
    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let generator = OutfitGenerator()

    private struct Saved: Codable {
        var current: Outfit?
        var history: [Outfit]
    }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("closet", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("outfit.json")
        if let data = try? Data(contentsOf: fileURL), let saved = try? JSONDecoder().decode(Saved.self, from: data) {
            current = saved.current
            history = saved.history
        }
    }

    /// Makes sure the current outfit only references pieces that still exist,
    /// generating a first outfit when there is none.
    func sync(with store: WardrobeStore) {
        let ids = Set(store.items.map(\.id))
        if let outfit = current {
            let pruned = outfit.pruned(keeping: ids)
            if pruned != outfit {
                current = pruned.isEmpty ? nil : pruned
                save()
            }
        }
        if current == nil, !store.items.isEmpty, !isGenerating {
            var rng = SystemRandomNumberGenerator()
            if let outfit = generator.generate(from: store.items, history: history, using: &rng) {
                present(outfit)
            }
        }
    }

    /// Clears the current outfit, shows the spinner for a beat, then lays out a new one.
    func regenerate(using store: WardrobeStore) {
        guard !isGenerating, !store.items.isEmpty else { return }
        isGenerating = true
        let items = store.items
        let history = self.history
        let generator = self.generator
        let started = Date()

        withAnimation(.easeIn(duration: 0.28)) { isClearing = true }

        Task { @MainActor in
            let next = await Task.detached(priority: .userInitiated) { () -> Outfit? in
                var rng = SystemRandomNumberGenerator()
                return generator.generate(from: items, history: history, using: &rng)
            }.value

            // Give the clear-out and spinner time to read as intentional.
            let elapsed = Date().timeIntervalSince(started)
            if elapsed < 0.8 {
                try? await Task.sleep(nanoseconds: UInt64((0.8 - elapsed) * 1_000_000_000))
            }
            if let next { present(next) }
            isClearing = false
            isGenerating = false
        }
    }

    /// Swaps a single piece, keeping the rest of the outfit.
    @discardableResult
    func reroll(_ slot: OutfitSlot, using store: WardrobeStore) -> Bool {
        guard let outfit = current, !isGenerating else { return false }
        var rng = SystemRandomNumberGenerator()
        guard let next = generator.reroll(slot: slot, in: outfit, items: store.items, history: history, using: &rng) else {
            return false
        }
        var updated = next
        updated.id = outfit.id
        current = updated
        history.append(updated)
        trimAndSave()
        return true
    }

    private func present(_ outfit: Outfit) {
        current = outfit
        history.append(outfit)
        trimAndSave()
    }

    private func trimAndSave() {
        if history.count > 12 { history.removeFirst(history.count - 12) }
        save()
    }

    private func save() {
        let saved = Saved(current: current, history: history)
        let url = fileURL
        DispatchQueue.global(qos: .utility).async {
            guard let data = try? JSONEncoder().encode(saved) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}
