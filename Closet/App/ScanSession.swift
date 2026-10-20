import Observation
import UIKit

/// The editable fields of a piece of clothing while it is being added or edited.
struct ItemDraft {
    /// nil while adding a new piece.
    var itemID: UUID?
    var name: String = ""
    var category: ClothingCategory = .shirts
    var color: RGBColor = RGBColor(white: 0.5)
    var primaryAttribute: String = ""
    var secondaryAttribute: String = ""
    var isFavorite = false
    /// A newly captured image, if any. Otherwise the stored image is kept.
    var newImage: UIImage?
    var existingImageFile: String = ""
    var createdAt = Date()

    var isNew: Bool { itemID == nil }

    init() {}

    init(item: ClothingItem) {
        itemID = item.id
        name = item.name
        category = item.category
        color = item.color
        primaryAttribute = item.primaryAttribute
        secondaryAttribute = item.secondaryAttribute
        isFavorite = item.isFavorite
        existingImageFile = item.imageFileName
        createdAt = item.createdAt
    }

    var image: UIImage? {
        newImage ?? ImageStore.shared.thumbnail(named: existingImageFile, maxPixel: 1000)
    }

    /// Changes whenever the image does, for refreshing derived state.
    var imageKey: String {
        if let newImage { return "new-\(ObjectIdentifier(newImage).hashValue)" }
        return existingImageFile
    }

    var suggestedName: String {
        "\(ColorNaming.name(for: color)) \(category.singular)"
    }
}

/// State shared by the scan → review → details flow.
@Observable
final class ScanSession {
    var capture: BackgroundRemover.Result?
    var useOriginal = false
    var draft: ItemDraft?
    /// The category Vision guessed for the latest capture.
    var suggestedCategory: ClothingCategory?
    /// True when the camera was opened from the editor to replace a photo.
    var returnsToEditor = false

    var result: UIImage? {
        guard let capture else { return nil }
        return useOriginal || !capture.lifted ? capture.original : capture.cutout
    }

    func reset() {
        capture = nil
        useOriginal = false
        draft = nil
        suggestedCategory = nil
        returnsToEditor = false
    }

    func beginEditing(_ item: ClothingItem) {
        reset()
        draft = ItemDraft(item: item)
    }

    func beginRetake() {
        capture = nil
        useOriginal = false
        returnsToEditor = true
    }

    /// Moves the reviewed photo into the draft, creating one for a new piece.
    func commitCapture() {
        guard let image = result else { return }
        if var existing = draft {
            existing.newImage = image
            draft = existing
        } else {
            var fresh = ItemDraft()
            fresh.newImage = image
            fresh.color = image.dominantColor() ?? RGBColor(white: 0.5)
            fresh.category = suggestedCategory ?? .shirts
            draft = fresh
        }
        returnsToEditor = false
    }
}
