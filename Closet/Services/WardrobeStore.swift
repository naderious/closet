import Foundation
import Observation

/// The user's wardrobe, persisted as JSON next to the images.
@Observable
final class WardrobeStore {
    private(set) var items: [ClothingItem] = []

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let saveQueue = DispatchQueue(label: "closet.wardrobe.save", qos: .utility)

    init(fileName: String = "wardrobe.json") {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("closet", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent(fileName)
        load()
    }

    // MARK: Queries

    func items(in category: ClothingCategory) -> [ClothingItem] {
        items.filter { $0.category == category }
    }

    var favorites: [ClothingItem] {
        items.filter(\.isFavorite)
    }

    func item(_ id: UUID?) -> ClothingItem? {
        guard let id else { return nil }
        return items.first { $0.id == id }
    }

    // MARK: Changes

    func add(_ item: ClothingItem) {
        items.append(item)
        persist()
    }

    func update(_ item: ClothingItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let previousImage = items[index].imageFileName
        items[index] = item
        if previousImage != item.imageFileName {
            ImageStore.shared.delete(named: previousImage)
        }
        persist()
    }

    func delete(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let removed = items.remove(at: index)
        ImageStore.shared.delete(named: removed.imageFileName)
        persist()
    }

    func toggleFavorite(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isFavorite.toggle()
        persist()
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        items = (try? decoder.decode([ClothingItem].self, from: data)) ?? []
    }

    private func persist() {
        let snapshot = items
        let url = fileURL
        saveQueue.async {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}
