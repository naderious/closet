import Foundation

/// Straight (non-premultiplied) 8-bit RGBA pixels, row-major.
struct RGBABuffer {
    var width: Int
    var height: Int
    var pixels: [UInt8]

    init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    var alpha: [UInt8] {
        var result = [UInt8](repeating: 0, count: width * height)
        for index in 0..<(width * height) { result[index] = pixels[index * 4 + 3] }
        return result
    }
}

/// A simple background remover used when Vision's subject lifting is unavailable
/// (e.g. the Simulator). Flood-fills the background inwards from the image border.
enum BackgroundMask {
    struct Box: Equatable {
        var x: Int, y: Int, width: Int, height: Int
    }

    /// Returns an alpha mask (0 = background, 255 = garment) or nil when no clear subject was found.
    static func floodFillMask(_ image: RGBABuffer) -> [UInt8]? {
        let width = image.width
        let height = image.height
        let count = width * height
        guard width > 8, height > 8, image.pixels.count >= count * 4 else { return nil }
        let px = image.pixels

        // Reference color: per-channel median of the border.
        var borderIndices: [Int] = []
        borderIndices.reserveCapacity(2 * (width + height))
        for x in 0..<width {
            borderIndices.append(x)
            borderIndices.append((height - 1) * width + x)
        }
        for y in 1..<(height - 1) {
            borderIndices.append(y * width)
            borderIndices.append(y * width + width - 1)
        }
        func median(_ channel: Int) -> Double {
            let values = borderIndices.map { px[$0 * 4 + channel] }.sorted()
            return Double(values[values.count / 2])
        }
        let reference = (median(0), median(1), median(2))

        var distance = [Float](repeating: 0, count: count)
        for index in 0..<count {
            let dr = Double(px[index * 4]) - reference.0
            let dg = Double(px[index * 4 + 1]) - reference.1
            let db = Double(px[index * 4 + 2]) - reference.2
            distance[index] = Float((dr * dr + dg * dg + db * db).squareRoot())
        }

        // Tolerance adapts to how busy the background is.
        let borderDistances = borderIndices.map { distance[$0] }.sorted()
        let spread = borderDistances[Int(Double(borderDistances.count) * 0.75)]
        let tolerance = min(max(spread * 1.8 + 16, 22), 75)

        var isBackground = [Bool](repeating: false, count: count)
        var queue: [Int] = []
        queue.reserveCapacity(count / 4)
        for index in borderIndices where distance[index] < tolerance && !isBackground[index] {
            isBackground[index] = true
            queue.append(index)
        }
        floodFill(&queue, &isBackground, width: width, height: height) { distance[$0] < tolerance }

        // Enclosed background (e.g. inside a belt loop) that closely matches the border color.
        var visited = isBackground
        let holeThreshold = tolerance * 0.5
        let minHole = max(16, count / 500)
        for start in 0..<count where !visited[start] && distance[start] < holeThreshold {
            var region = [start]
            var regionQueue = [start]
            visited[start] = true
            var head = 0
            while head < regionQueue.count {
                let index = regionQueue[head]
                head += 1
                for neighbor in neighbors(of: index, width: width, height: height)
                where !visited[neighbor] && distance[neighbor] < holeThreshold {
                    visited[neighbor] = true
                    regionQueue.append(neighbor)
                    region.append(neighbor)
                }
            }
            if region.count >= minHole {
                for index in region { isBackground[index] = true }
            }
        }

        var mask = [UInt8](repeating: 0, count: count)
        for index in 0..<count where !isBackground[index] { mask[index] = 255 }
        removeSpecks(&mask, width: width, height: height)

        let foreground = mask.reduce(0) { $0 + ($1 > 0 ? 1 : 0) }
        let share = Double(foreground) / Double(count)
        guard share > 0.02, share < 0.97 else { return nil }
        return feather(mask, width: width, height: height)
    }

    /// The bounding box of pixels above the threshold.
    static func boundingBox(of mask: [UInt8], width: Int, height: Int, threshold: UInt8 = 12) -> Box? {
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            let row = y * width
            for x in 0..<width where mask[row + x] > threshold {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return Box(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    // MARK: Helpers

    private static func neighbors(of index: Int, width: Int, height: Int) -> [Int] {
        let x = index % width
        let y = index / width
        var result: [Int] = []
        result.reserveCapacity(4)
        if x > 0 { result.append(index - 1) }
        if x < width - 1 { result.append(index + 1) }
        if y > 0 { result.append(index - width) }
        if y < height - 1 { result.append(index + width) }
        return result
    }

    private static func floodFill(
        _ queue: inout [Int], _ marked: inout [Bool], width: Int, height: Int, accept: (Int) -> Bool
    ) {
        var head = 0
        while head < queue.count {
            let index = queue[head]
            head += 1
            for neighbor in neighbors(of: index, width: width, height: height) where !marked[neighbor] && accept(neighbor) {
                marked[neighbor] = true
                queue.append(neighbor)
            }
        }
    }

    /// Drops foreground islands much smaller than the main subject.
    private static func removeSpecks(_ mask: inout [UInt8], width: Int, height: Int) {
        let count = width * height
        var label = [Int32](repeating: -1, count: count)
        var sizes: [Int] = []
        for start in 0..<count where mask[start] > 0 && label[start] < 0 {
            let id = Int32(sizes.count)
            var queue = [start]
            label[start] = id
            var head = 0
            while head < queue.count {
                let index = queue[head]
                head += 1
                for neighbor in neighbors(of: index, width: width, height: height) where mask[neighbor] > 0 && label[neighbor] < 0 {
                    label[neighbor] = id
                    queue.append(neighbor)
                }
            }
            sizes.append(queue.count)
        }
        guard let largest = sizes.max(), largest > 0 else { return }
        let minimum = max(1, largest / 25)
        for index in 0..<count where label[index] >= 0 && sizes[Int(label[index])] < minimum {
            mask[index] = 0
        }
    }

    /// Softens the cut edge with a 3×3 box blur.
    private static func feather(_ mask: [UInt8], width: Int, height: Int) -> [UInt8] {
        var result = mask
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var sum = 0
                for dy in -1...1 {
                    let row = (y + dy) * width
                    for dx in -1...1 { sum += Int(mask[row + x + dx]) }
                }
                result[y * width + x] = UInt8(sum / 9)
            }
        }
        return result
    }
}

/// Finds the main color of a garment, ignoring transparent pixels.
enum DominantColor {
    static func compute(_ image: RGBABuffer, alphaThreshold: UInt8 = 200, clusters: Int = 4) -> RGBColor? {
        let count = image.width * image.height
        guard count > 0 else { return nil }
        let step = max(1, count / 5000)
        var samples: [OKLab] = []
        var index = 0
        while index < count {
            let offset = index * 4
            if image.pixels[offset + 3] >= alphaThreshold {
                let color = RGBColor(
                    r: Double(image.pixels[offset]) / 255,
                    g: Double(image.pixels[offset + 1]) / 255,
                    b: Double(image.pixels[offset + 2]) / 255
                )
                samples.append(color.oklab)
            }
            index += step
        }
        guard !samples.isEmpty else { return nil }
        let k = min(clusters, samples.count)

        // k-means in OKLab, seeded deterministically across the lightness range.
        let sortedByLightness = samples.sorted { $0.l < $1.l }
        let total = sortedByLightness.count
        var centroids: [OKLab] = []
        for cluster in 0..<k {
            let position: Int = (cluster * 2 + 1) * total / (2 * k)
            centroids.append(sortedByLightness[min(total - 1, position)])
        }
        var assignments = [Int](repeating: 0, count: samples.count)
        for _ in 0..<12 {
            for (sampleIndex, sample) in samples.enumerated() {
                var best = 0
                var bestDistance = Double.greatestFiniteMagnitude
                for (centroidIndex, centroid) in centroids.enumerated() {
                    let distance = sample.distance(to: centroid)
                    if distance < bestDistance {
                        bestDistance = distance
                        best = centroidIndex
                    }
                }
                assignments[sampleIndex] = best
            }
            var sums = [OKLab](repeating: OKLab(l: 0, a: 0, b: 0), count: k)
            var counts = [Int](repeating: 0, count: k)
            for (sampleIndex, sample) in samples.enumerated() {
                let cluster = assignments[sampleIndex]
                sums[cluster].l += sample.l
                sums[cluster].a += sample.a
                sums[cluster].b += sample.b
                counts[cluster] += 1
            }
            for cluster in 0..<k where counts[cluster] > 0 {
                let n = Double(counts[cluster])
                centroids[cluster] = OKLab(l: sums[cluster].l / n, a: sums[cluster].a / n, b: sums[cluster].b / n)
            }
        }

        var counts = [Int](repeating: 0, count: k)
        for cluster in assignments { counts[cluster] += 1 }
        guard let biggest = counts.indices.max(by: { counts[$0] < counts[$1] }) else { return nil }
        return RGBColor(oklab: centroids[biggest])
    }
}
