import Foundation

/// The silhouette of a background-removed image: for evenly spaced rows, the
/// normalised x position of the first and last opaque pixel. Used to make the
/// outfit callout lines start exactly at the edge of a garment.
struct EdgeProfile: Codable, Hashable {
    static let rowCount = 48

    /// 0...1, or -1 when the row has no opaque pixels.
    var leading: [Double]
    var trailing: [Double]

    static func make(alpha: [UInt8], width: Int, height: Int, threshold: UInt8 = 40) -> EdgeProfile {
        var leading = [Double](repeating: -1, count: rowCount)
        var trailing = [Double](repeating: -1, count: rowCount)
        guard width > 0, height > 0, alpha.count >= width * height else {
            return EdgeProfile(leading: leading, trailing: trailing)
        }
        for row in 0..<rowCount {
            let startY = row * height / rowCount
            let endY = max(startY + 1, (row + 1) * height / rowCount)
            var minX = Int.max
            var maxX = Int.min
            for y in startY..<min(endY, height) {
                let base = y * width
                var x = 0
                while x < width {
                    if alpha[base + x] > threshold { minX = min(minX, x); break }
                    x += 1
                }
                x = width - 1
                while x >= 0 {
                    if alpha[base + x] > threshold { maxX = max(maxX, x); break }
                    x -= 1
                }
            }
            if minX != Int.max, maxX != Int.min {
                leading[row] = Double(minX) / Double(width)
                trailing[row] = Double(maxX + 1) / Double(width)
            }
        }
        return EdgeProfile(leading: leading, trailing: trailing)
    }

    /// Leading edge at a normalised height (0 = top, 1 = bottom).
    func leadingEdge(at y: Double) -> Double {
        value(in: leading, at: y) ?? 0
    }

    /// Trailing edge at a normalised height (0 = top, 1 = bottom).
    func trailingEdge(at y: Double) -> Double {
        value(in: trailing, at: y) ?? 1
    }

    private func value(in rows: [Double], at y: Double) -> Double? {
        guard !rows.isEmpty else { return nil }
        let index = Int((y.clamped(to: 0...1) * Double(rows.count)).rounded(.down)).clamped(to: 0...(rows.count - 1))
        if rows[index] >= 0 { return rows[index] }
        // Walk outwards to the nearest row that has content.
        for offset in 1..<rows.count {
            if index - offset >= 0, rows[index - offset] >= 0 { return rows[index - offset] }
            if index + offset < rows.count, rows[index + offset] >= 0 { return rows[index + offset] }
        }
        return nil
    }
}
