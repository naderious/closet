import Foundation

/// An sRGB color with components in 0...1.
struct RGBColor: Codable, Hashable {
    var r: Double
    var g: Double
    var b: Double

    init(r: Double, g: Double, b: Double) {
        self.r = r.clamped(to: 0...1)
        self.g = g.clamped(to: 0...1)
        self.b = b.clamped(to: 0...1)
    }

    init(white: Double) {
        self.init(r: white, g: white, b: white)
    }

    init?(hex: String) {
        var string = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if string.hasPrefix("#") { string.removeFirst() }
        if string.count == 3 {
            string = string.map { "\($0)\($0)" }.joined()
        }
        guard string.count == 6, let value = UInt32(string, radix: 16) else { return nil }
        self.init(
            r: Double((value >> 16) & 0xFF) / 255,
            g: Double((value >> 8) & 0xFF) / 255,
            b: Double(value & 0xFF) / 255
        )
    }

    var hex: String {
        let red = Int((r * 255).rounded())
        let green = Int((g * 255).rounded())
        let blue = Int((b * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    // MARK: HSB

    init(hue: Double, saturation: Double, brightness: Double) {
        let h = (hue - floor(hue)) * 6
        let s = saturation.clamped(to: 0...1)
        let v = brightness.clamped(to: 0...1)
        let sector = Int(h) % 6
        let f = h - floor(h)
        let p = v * (1 - s)
        let q = v * (1 - s * f)
        let t = v * (1 - s * (1 - f))
        switch sector {
        case 0: self.init(r: v, g: t, b: p)
        case 1: self.init(r: q, g: v, b: p)
        case 2: self.init(r: p, g: v, b: t)
        case 3: self.init(r: p, g: q, b: v)
        case 4: self.init(r: t, g: p, b: v)
        default: self.init(r: v, g: p, b: q)
        }
    }

    /// Hue (0..<1), saturation and brightness (0...1).
    var hsb: (hue: Double, saturation: Double, brightness: Double) {
        let maxValue = max(r, g, b)
        let minValue = min(r, g, b)
        let delta = maxValue - minValue
        var hue = 0.0
        if delta > 0 {
            if maxValue == r {
                hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxValue == g {
                hue = (b - r) / delta + 2
            } else {
                hue = (r - g) / delta + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        let saturation = maxValue == 0 ? 0 : delta / maxValue
        return (hue, saturation, maxValue)
    }

    // MARK: Perceptual spaces

    var oklab: OKLab {
        let lr = RGBColor.linearize(r)
        let lg = RGBColor.linearize(g)
        let lb = RGBColor.linearize(b)
        let l = cbrt(0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb)
        let m = cbrt(0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb)
        let s = cbrt(0.0883024619 * lr + 0.2817188376 * lg + 0.6299787005 * lb)
        return OKLab(
            l: 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            a: 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            b: 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        )
    }

    init(oklab: OKLab) {
        let l_ = oklab.l + 0.3963377774 * oklab.a + 0.2158037573 * oklab.b
        let m_ = oklab.l - 0.1055613458 * oklab.a - 0.0638541728 * oklab.b
        let s_ = oklab.l - 0.0894841775 * oklab.a - 1.2914855480 * oklab.b
        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_
        self.init(
            r: RGBColor.gammaEncode(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
            g: RGBColor.gammaEncode(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
            b: RGBColor.gammaEncode(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
        )
    }

    var oklch: OKLCH { oklab.lch }

    /// The hue on the painter's (red–yellow–blue) color wheel, in degrees.
    /// Fashion color rules (complementary, triadic…) are defined on this wheel,
    /// so red pairs with green and blue with orange.
    var artisticHue: Double {
        RGBColor.rybHue(fromRGBHue: hsb.hue * 360)
    }

    func distance(to other: RGBColor) -> Double {
        oklab.distance(to: other.oklab)
    }

    func mixed(with other: RGBColor, amount: Double) -> RGBColor {
        let t = amount.clamped(to: 0...1)
        return RGBColor(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t)
    }

    static func linearize(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    static func gammaEncode(_ value: Double) -> Double {
        let v = max(0, value)
        return v <= 0.0031308 ? 12.92 * v : 1.055 * pow(v, 1 / 2.4) - 0.055
    }

    static func rybHue(fromRGBHue hue: Double) -> Double {
        let h = (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        // Piecewise mapping of RGB hue anchors onto the RYB wheel.
        let anchors: [(rgb: Double, ryb: Double)] = [
            (0, 0), (30, 60), (60, 120), (120, 180), (180, 210), (240, 240), (300, 300), (360, 360),
        ]
        for index in 1..<anchors.count where h <= anchors[index].rgb {
            let lower = anchors[index - 1]
            let upper = anchors[index]
            let t = (h - lower.rgb) / (upper.rgb - lower.rgb)
            return lower.ryb + (upper.ryb - lower.ryb) * t
        }
        return h
    }

    static let black = RGBColor(white: 0)
    static let white = RGBColor(white: 1)
}

struct OKLab: Hashable {
    var l: Double
    var a: Double
    var b: Double

    var lch: OKLCH {
        let chroma = sqrt(a * a + b * b)
        var hue = atan2(b, a) * 180 / .pi
        if hue < 0 { hue += 360 }
        return OKLCH(l: l, c: chroma, h: hue)
    }

    func distance(to other: OKLab) -> Double {
        let dl = l - other.l
        let da = a - other.a
        let db = b - other.b
        return sqrt(dl * dl + da * da + db * db)
    }
}

struct OKLCH: Hashable {
    var l: Double
    var c: Double
    /// Degrees, 0..<360.
    var h: Double
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

enum Angles {
    /// Shortest distance between two angles in degrees (0...180).
    static func distance(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(d, 360 - d)
    }
}
