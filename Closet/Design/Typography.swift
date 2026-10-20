import CoreText
import SwiftUI
import UIKit

enum TypeWeight {
    case bold, regular
}

/// Finds the GT America files bundled in `Resources/Fonts`, registers them, and picks
/// the best bold and regular faces. Drop any GT America .otf/.ttf files into that
/// folder and they are used automatically; until then the app falls back to the
/// system's expanded San Francisco, which shares the same wide, calm proportions.
final class FontRegistry {
    static let shared = FontRegistry()

    enum Face: Equatable {
        case system
        case named(String)
        case variable(name: String, weight: Double, width: Double?)
    }

    private(set) var bold: Face = .system
    private(set) var regular: Face = .system
    private var activated = false

    private static let weightAxis = 0x7767_6874 // 'wght'
    private static let widthAxis = 0x7764_7468 // 'wdth'

    private struct Candidate {
        var postScriptName: String
        var family: String
        var weight: Double
        var widthRank: Int
        var isGTAmerica: Bool
        var axes: [Int: ClosedRange<Double>]
    }

    func activate() {
        guard !activated else { return }
        activated = true

        let extensions = ["otf", "ttf", "OTF", "TTF"]
        var urls = Set<URL>()
        for ext in extensions {
            for directory in [nil, "Fonts", "Resources/Fonts"] as [String?] {
                Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: directory)?.forEach { urls.insert($0) }
            }
        }

        var candidates: [Candidate] = []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] else {
                continue
            }
            for descriptor in descriptors {
                guard let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String else { continue }
                let family = CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String ?? ""
                let style = CTFontDescriptorCopyAttribute(descriptor, kCTFontStyleNameAttribute) as? String ?? ""
                let text = "\(family) \(style) \(name)".lowercased()
                if text.contains("italic") || text.contains("oblique") || text.contains("mono") { continue }

                var axes: [Int: ClosedRange<Double>] = [:]
                let font = CTFontCreateWithFontDescriptor(descriptor, 12, nil)
                if let list = CTFontCopyVariationAxes(font) as? [[String: Any]] {
                    for axis in list {
                        guard
                            let identifier = (axis[kCTFontVariationAxisIdentifierKey as String] as? NSNumber)?.intValue,
                            let minimum = (axis[kCTFontVariationAxisMinimumValueKey as String] as? NSNumber)?.doubleValue,
                            let maximum = (axis[kCTFontVariationAxisMaximumValueKey as String] as? NSNumber)?.doubleValue,
                            minimum <= maximum
                        else { continue }
                        axes[identifier] = minimum...maximum
                    }
                }

                candidates.append(Candidate(
                    postScriptName: name,
                    family: family,
                    weight: FontRegistry.weight(from: "\(style) \(name)"),
                    widthRank: FontRegistry.widthRank(from: text),
                    isGTAmerica: text.contains("gt america") || text.contains("gtamerica") || text.contains("gt-america"),
                    axes: axes
                ))
            }
        }
        choose(from: candidates)
    }

    private func choose(from all: [Candidate]) {
        let pool = all.contains(where: \.isGTAmerica) ? all.filter(\.isGTAmerica) : all
        guard !pool.isEmpty else { return }

        // A variable font can cover both roles on its own.
        if let variable = pool.first(where: { $0.axes[FontRegistry.weightAxis] != nil }) {
            let weights = variable.axes[FontRegistry.weightAxis]!
            let width = variable.axes[FontRegistry.widthAxis]?.upperBound
            bold = .variable(name: variable.postScriptName, weight: min(weights.upperBound, 850), width: width)
            regular = .variable(name: variable.postScriptName, weight: Double(400).clamped(to: weights), width: width)
            return
        }

        // Prefer the widest cut that has both a heavy and a regular face (Expanded > Extended > Standard).
        let ranks = Set(pool.map(\.widthRank)).sorted(by: >)
        let completeRank = ranks.first { rank in
            pool.contains { $0.widthRank == rank && $0.weight >= 600 } && pool.contains { $0.widthRank == rank && $0.weight <= 500 }
        }
        let rank = completeRank ?? ranks.first ?? 2
        let tier = pool.filter { $0.widthRank == rank }

        if let heavy = tier.filter({ $0.weight >= 600 }).min(by: { abs($0.weight - 880) < abs($1.weight - 880) }) {
            bold = .named(heavy.postScriptName)
        }
        if let book = tier.filter({ $0.weight <= 500 }).min(by: { abs($0.weight - 400) < abs($1.weight - 400) }) {
            regular = .named(book.postScriptName)
        }
    }

    // MARK: Fonts

    func font(_ weight: TypeWeight, size: CGFloat) -> Font {
        switch face(for: weight) {
        case .system:
            return Font.system(size: size, weight: weight == .bold ? .black : .regular).width(.expanded)
        case .named(let name):
            return Font.custom(name, fixedSize: size)
        case .variable:
            return Font(uiFont(weight, size: size) as CTFont)
        }
    }

    func uiFont(_ weight: TypeWeight, size: CGFloat) -> UIFont {
        switch face(for: weight) {
        case .system:
            return UIFont.systemFont(ofSize: size, weight: weight == .bold ? .black : .regular, width: .expanded)
        case .named(let name):
            return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size)
        case .variable(let name, let value, let width):
            var variations: [NSNumber: NSNumber] = [NSNumber(value: FontRegistry.weightAxis): NSNumber(value: value)]
            if let width {
                variations[NSNumber(value: FontRegistry.widthAxis)] = NSNumber(value: width)
            }
            let descriptor = UIFontDescriptor(fontAttributes: [
                .name: name,
                UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variations,
            ])
            return UIFont(descriptor: descriptor, size: size)
        }
    }

    private func face(for weight: TypeWeight) -> Face {
        weight == .bold ? bold : regular
    }

    // MARK: Name parsing

    private static func weight(from text: String) -> Double {
        let t = text.lowercased()
        if t.contains("hairline") || t.contains("thin") { return 100 }
        if t.contains("ultralight") || t.contains("ultra light") || t.contains("extralight") || t.contains("extra light") { return 200 }
        if t.contains("light") { return 300 }
        if t.contains("medium") { return 500 }
        if t.contains("semibold") || t.contains("semi bold") || t.contains("demibold") { return 600 }
        if t.contains("extrabold") || t.contains("extra bold") || t.contains("ultrabold") { return 800 }
        if t.contains("black") || t.contains("heavy") || t.contains("ultra") { return 900 }
        if t.contains("bold") { return 700 }
        return 400
    }

    private static func widthRank(from text: String) -> Int {
        if text.contains("compressed") { return 0 }
        if text.contains("condensed") { return 1 }
        if text.contains("expanded") { return 4 }
        if text.contains("extended") { return 3 }
        return 2
    }
}

extension Font {
    static func closet(_ weight: TypeWeight, _ size: CGFloat) -> Font {
        FontRegistry.shared.font(weight, size: size)
    }
}

/// The type scale, measured from the mockups.
enum TypeScale {
    static let wordmark: CGFloat = 40
    static let pageTitle: CGFloat = 44
    static let cardTitle: CGFloat = 22
    static let cardCount: CGFloat = 16
    static let cardMeta: CGFloat = 9
    static let body: CGFloat = 12.5
    static let callout: CGFloat = 10.5
    static let button: CGFloat = 16
    static let chip: CGFloat = 11
}

extension View {
    /// Bold, slightly tightened display type.
    func displayType(_ size: CGFloat) -> some View {
        font(.closet(.bold, size)).tracking(-size * 0.025)
    }
}
