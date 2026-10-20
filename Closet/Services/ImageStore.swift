import ImageIO
import UIKit

/// Stores background-removed garment images as PNG files in Application Support,
/// with in-memory caches for full images and thumbnails.
final class ImageStore {
    static let shared = ImageStore()

    let directory: URL
    private let images = NSCache<NSString, UIImage>()
    private let thumbnails = NSCache<NSString, UIImage>()

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("closet/images", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        images.countLimit = 40
        thumbnails.countLimit = 300
    }

    func url(for name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    @discardableResult
    func save(_ image: UIImage) throws -> String {
        guard let data = image.pngData() else { throw CocoaError(.fileWriteUnknown) }
        let name = UUID().uuidString + ".png"
        try data.write(to: url(for: name), options: .atomic)
        images.setObject(image, forKey: name as NSString)
        return name
    }

    func cachedImage(named name: String) -> UIImage? {
        images.object(forKey: name as NSString)
    }

    func cachedThumbnail(named name: String, maxPixel: Int) -> UIImage? {
        thumbnails.object(forKey: "\(name)@\(maxPixel)" as NSString)
    }

    func image(named name: String) -> UIImage? {
        guard !name.isEmpty else { return nil }
        if let cached = images.object(forKey: name as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: url(for: name).path) else { return nil }
        let decoded = image.preparingForDisplay() ?? image
        images.setObject(decoded, forKey: name as NSString)
        return decoded
    }

    func thumbnail(named name: String, maxPixel: Int = 320) -> UIImage? {
        guard !name.isEmpty else { return nil }
        let key = "\(name)@\(maxPixel)" as NSString
        if let cached = thumbnails.object(forKey: key) { return cached }
        guard let source = CGImageSourceCreateWithURL(url(for: name) as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let thumbnail = UIImage(cgImage: cgImage)
        thumbnails.setObject(thumbnail, forKey: key)
        return thumbnail
    }

    func delete(named name: String) {
        guard !name.isEmpty else { return }
        images.removeObject(forKey: name as NSString)
        try? FileManager.default.removeItem(at: url(for: name))
    }
}
