import CoreImage
import UIKit
import Vision

extension UIImage {
    /// Redraws the image upright (applying EXIF orientation), optionally downscaled.
    func normalized(maxDimension: CGFloat) -> UIImage {
        let pixelWidth = size.width * scale
        let pixelHeight = size.height * scale
        let longest = max(pixelWidth, pixelHeight)
        let factor = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: (pixelWidth * factor).rounded(), height: (pixelHeight * factor).rounded())
        if imageOrientation == .up, factor == 1, cgImage != nil { return self }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Straight-alpha RGBA pixels, downscaled so the longest side is at most `maxDimension`.
    func rgbaBuffer(maxDimension: CGFloat) -> RGBABuffer? {
        guard let cgImage = normalized(maxDimension: maxDimension).cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return nil }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { raw in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        // Un-premultiply so colors are true even at soft edges.
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Int(pixels[index + 3])
            if alpha > 0 && alpha < 255 {
                pixels[index] = UInt8(min(255, Int(pixels[index]) * 255 / alpha))
                pixels[index + 1] = UInt8(min(255, Int(pixels[index + 1]) * 255 / alpha))
                pixels[index + 2] = UInt8(min(255, Int(pixels[index + 2]) * 255 / alpha))
            }
        }
        return RGBABuffer(width: width, height: height, pixels: pixels)
    }

    convenience init?(buffer: RGBABuffer) {
        var pixels = buffer.pixels
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Int(pixels[index + 3])
            if alpha < 255 {
                pixels[index] = UInt8(Int(pixels[index]) * alpha / 255)
                pixels[index + 1] = UInt8(Int(pixels[index + 1]) * alpha / 255)
                pixels[index + 2] = UInt8(Int(pixels[index + 2]) * alpha / 255)
            }
        }
        guard
            let provider = CGDataProvider(data: Data(pixels) as CFData),
            let cgImage = CGImage(
                width: buffer.width,
                height: buffer.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: buffer.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )
        else { return nil }
        self.init(cgImage: cgImage)
    }

    /// Crops away fully transparent margins.
    func croppedToOpaqueBounds() -> UIImage {
        guard let cgImage, let buffer = rgbaBuffer(maxDimension: 512) else { return self }
        guard let box = BackgroundMask.boundingBox(of: buffer.alpha, width: buffer.width, height: buffer.height) else {
            return self
        }
        let sx = CGFloat(cgImage.width) / CGFloat(buffer.width)
        let sy = CGFloat(cgImage.height) / CGFloat(buffer.height)
        let rect = CGRect(
            x: CGFloat(box.x) * sx, y: CGFloat(box.y) * sy,
            width: CGFloat(box.width) * sx, height: CGFloat(box.height) * sy
        ).insetBy(dx: -2, dy: -2).integral
            .intersection(CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        guard let cropped = cgImage.cropping(to: rect) else { return self }
        return UIImage(cgImage: cropped)
    }

    var pixelAspect: Double {
        guard size.height > 0 else { return 1 }
        return Double(size.width / size.height)
    }

    func edgeProfile() -> EdgeProfile? {
        guard let buffer = rgbaBuffer(maxDimension: 256) else { return nil }
        return EdgeProfile.make(alpha: buffer.alpha, width: buffer.width, height: buffer.height)
    }

    func dominantColor() -> RGBColor? {
        guard let buffer = rgbaBuffer(maxDimension: 120) else { return nil }
        return DominantColor.compute(buffer)
    }
}

/// Lifts the garment off its background: Vision's subject lifting first, then a
/// flood-fill fallback for the Simulator and older hardware.
enum BackgroundRemover {
    struct Result {
        var original: UIImage
        var cutout: UIImage
        var lifted: Bool
    }

    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    static func lift(_ image: UIImage) async -> Result {
        await Task.detached(priority: .userInitiated) {
            let prepared = image.normalized(maxDimension: 1800)
            if let cutout = visionLift(prepared) ?? floodFillLift(prepared) {
                return Result(original: prepared, cutout: cutout, lifted: true)
            }
            return Result(original: prepared, cutout: prepared, lifted: false)
        }.value
    }

    private static func visionLift(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        do {
            try handler.perform([request])
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else { return nil }
            let buffer = try observation.generateMaskedImage(
                ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: true
            )
            let ciImage = CIImage(cvPixelBuffer: buffer)
            guard let output = context.createCGImage(
                ciImage,
                from: ciImage.extent,
                format: .RGBA8,
                colorSpace: CGColorSpace(name: CGColorSpace.sRGB)
            ) else { return nil }
            return UIImage(cgImage: output).croppedToOpaqueBounds()
        } catch {
            return nil
        }
    }

    private static func floodFillLift(_ image: UIImage) -> UIImage? {
        guard var buffer = image.rgbaBuffer(maxDimension: 1000) else { return nil }
        guard let mask = BackgroundMask.floodFillMask(buffer),
              let box = BackgroundMask.boundingBox(of: mask, width: buffer.width, height: buffer.height)
        else { return nil }
        for index in 0..<(buffer.width * buffer.height) {
            buffer.pixels[index * 4 + 3] = mask[index]
        }
        guard let masked = UIImage(buffer: buffer), let cgImage = masked.cgImage,
              let cropped = cgImage.cropping(to: CGRect(x: box.x, y: box.y, width: box.width, height: box.height))
        else { return nil }
        return UIImage(cgImage: cropped)
    }
}

/// Suggests a category from the photo using Vision's built-in image classifier.
enum ClothingClassifier {
    static func suggestCategory(for image: UIImage) async -> ClothingCategory? {
        await Task.detached(priority: .utility) { () -> ClothingCategory? in
            guard let cgImage = image.normalized(maxDimension: 800).cgImage else { return nil }
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            guard (try? handler.perform([request])) != nil, let results = request.results else { return nil }
            let ranked = results.filter { $0.confidence > 0.12 }.sorted { $0.confidence > $1.confidence }.prefix(25)
            for observation in ranked {
                if let category = category(for: observation.identifier) { return category }
            }
            return nil
        }.value
    }

    static func category(for identifier: String) -> ClothingCategory? {
        let tokens = Set(identifier.lowercased().split(whereSeparator: { $0 == "_" || $0 == " " || $0 == "-" }).map(String.init))
        func any(_ words: [String]) -> Bool { !tokens.isDisjoint(with: words) }
        if any(["jeans", "denim"]) { return .jeans }
        if any(["pants", "trousers", "shorts", "leggings", "chinos"]) { return .pants }
        if any(["shoe", "shoes", "sneaker", "sneakers", "boot", "boots", "footwear", "sandal", "sandals", "loafer", "heel", "heels"]) {
            return .shoes
        }
        if any(["belt"]) { return .belts }
        if any(["jacket", "coat", "blazer", "outerwear", "parka", "vest", "windbreaker"]) { return .jackets }
        if any(["sweater", "cardigan", "hoodie", "sweatshirt", "pullover", "jumper"]) { return .sweaters }
        if any(["shirt", "tshirt", "t", "blouse", "jersey", "polo", "tank"]) && !tokens.contains("sweatshirt") { return .shirts }
        return nil
    }
}

/// Reads colors from a cutout for the eyedropper.
final class PixelSampler {
    private let buffer: RGBABuffer

    init?(image: UIImage) {
        guard let buffer = image.rgbaBuffer(maxDimension: 420) else { return nil }
        self.buffer = buffer
    }

    /// Averages opaque pixels around a normalised point (0...1 in both axes).
    func color(at point: CGPoint) -> RGBColor? {
        let cx = Int((point.x * CGFloat(buffer.width)).rounded(.down))
        let cy = Int((point.y * CGFloat(buffer.height)).rounded(.down))
        var r = 0, g = 0, b = 0, count = 0
        for y in (cy - 2)...(cy + 2) where y >= 0 && y < buffer.height {
            for x in (cx - 2)...(cx + 2) where x >= 0 && x < buffer.width {
                let offset = (y * buffer.width + x) * 4
                guard buffer.pixels[offset + 3] > 140 else { continue }
                r += Int(buffer.pixels[offset])
                g += Int(buffer.pixels[offset + 1])
                b += Int(buffer.pixels[offset + 2])
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return RGBColor(r: Double(r) / Double(count * 255), g: Double(g) / Double(count * 255), b: Double(b) / Double(count * 255))
    }
}
