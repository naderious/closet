#if DEBUG
import SwiftUI
import UIKit

/// Debug-only launch arguments for previewing the app without scanning anything:
///
/// - `-seedDemo` fills an empty wardrobe with drawn sample pieces
/// - `-route home|wardrobe|scan|editor` opens a screen directly
/// - `-expandAll` unfolds every wardrobe section
///
/// Add them under Product → Scheme → Edit Scheme → Run → Arguments.
enum DebugLaunch {
    static func apply(router: Router, store: WardrobeStore, scan: ScanSession) {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-seedDemo"), store.items.isEmpty {
            for item in DemoWardrobe.make() { store.add(item) }
        }
        if arguments.contains("-expandAll") {
            router.expandedSections = Set(WardrobeSection.all.map(\.id))
        }
        if let index = arguments.firstIndex(of: "-route"), index + 1 < arguments.count {
            switch arguments[index + 1] {
            case "wardrobe": router.jump(to: .wardrobe)
            case "scan": router.jump(to: .scan)
            case "editor":
                if let item = store.items.first {
                    scan.beginEditing(item)
                    router.jump(to: .editor)
                }
            default: break
            }
        }
    }
}

/// Simple drawn garments so layouts and animations can be checked in the Simulator.
private enum DemoWardrobe {
    static func make() -> [ClothingItem] {
        [
            item("hysteric glamour tee", .shirts, "#ECE8DE", "cotton jersey", "fitted", image: tee(color: "#ECE8DE", longSleeves: false), favorite: true),
            item("mohair sweater", .sweaters, "#6B4528", "mohair", "boxy", image: tee(color: "#6B4528", longSleeves: true)),
            item("leather jacket", .jackets, "#141414", "leather", "cropped", image: jacket(color: "#141414")),
            item("menes fuka jeans", .jeans, "#3D5A80", "selvedge", "loose bootcut", image: jeans(color: "#3D5A80"), favorite: true),
            item("shinka archive denim", .jeans, "#121212", "selvedge", "bootcut", image: jeans(color: "#1A1A1A")),
            item("peoples fortune denim", .jeans, "#E2DED6", "bias tape", "slight bootcut", image: jeans(color: "#E2DED6")),
            item("ccp belt", .belts, "#151515", "leather", "silver", image: belt(color: "#151515")),
            item("ysl wyatt snakeskin", .shoes, "#1E1E1E", "snakeskin", "boots", image: boot(color: "#1E1E1E")),
        ]
    }

    private static func item(
        _ name: String, _ category: ClothingCategory, _ hex: String, _ primary: String, _ secondary: String,
        image: UIImage, favorite: Bool = false
    ) -> ClothingItem {
        let cutout = image.croppedToOpaqueBounds()
        let file = (try? ImageStore.shared.save(cutout)) ?? ""
        return ClothingItem(
            name: name, category: category, colorHex: hex, primaryAttribute: primary, secondaryAttribute: secondary,
            isFavorite: favorite, imageFileName: file, imageAspect: cutout.pixelAspect, edgeProfile: cutout.edgeProfile()
        )
    }

    private static func render(_ size: CGSize, _ draw: (CGContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { context in draw(context.cgContext) }
    }

    private static func fill(_ path: UIBezierPath, _ hex: String, in context: CGContext) {
        let base = RGBColor(hex: hex) ?? RGBColor(white: 0.5)
        UIColor(red: base.r, green: base.g, blue: base.b, alpha: 1).setFill()
        path.fill()
        // A soft vertical shade so the shapes don't read completely flat.
        context.saveGState()
        path.addClip()
        let colors = [UIColor.white.withAlphaComponent(0.10).cgColor, UIColor.black.withAlphaComponent(0.18).cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: path.bounds.minY), end: CGPoint(x: 0, y: path.bounds.maxY), options: [])
        }
        context.restoreGState()
    }

    private static func stroke(_ path: UIBezierPath, alpha: CGFloat = 0.25, width: CGFloat = 3) {
        UIColor(white: 0.5, alpha: alpha).setStroke()
        path.lineWidth = width
        path.stroke()
    }

    private static func tee(color: String, longSleeves: Bool) -> UIImage {
        render(CGSize(width: 640, height: 600)) { context in
            let body = UIBezierPath()
            let sleeveEnd: CGFloat = longSleeves ? 560 : 250
            body.move(to: CGPoint(x: 240, y: 40))
            body.addQuadCurve(to: CGPoint(x: 400, y: 40), controlPoint: CGPoint(x: 320, y: 110))
            body.addLine(to: CGPoint(x: 520, y: 80))
            body.addLine(to: CGPoint(x: longSleeves ? 610 : 630, y: sleeveEnd))
            body.addLine(to: CGPoint(x: longSleeves ? 545 : 540, y: sleeveEnd + 20))
            body.addLine(to: CGPoint(x: 490, y: longSleeves ? 230 : 220))
            body.addLine(to: CGPoint(x: 490, y: 580))
            body.addLine(to: CGPoint(x: 150, y: 580))
            body.addLine(to: CGPoint(x: 150, y: longSleeves ? 230 : 220))
            body.addLine(to: CGPoint(x: longSleeves ? 95 : 100, y: sleeveEnd + 20))
            body.addLine(to: CGPoint(x: longSleeves ? 30 : 10, y: sleeveEnd))
            body.addLine(to: CGPoint(x: 120, y: 80))
            body.close()
            fill(body, color, in: context)
            let collar = UIBezierPath()
            collar.move(to: CGPoint(x: 250, y: 46))
            collar.addQuadCurve(to: CGPoint(x: 390, y: 46), controlPoint: CGPoint(x: 320, y: 100))
            stroke(collar)
        }
    }

    private static func jacket(color: String) -> UIImage {
        render(CGSize(width: 640, height: 620)) { context in
            let body = UIBezierPath()
            body.move(to: CGPoint(x: 230, y: 30))
            body.addLine(to: CGPoint(x: 410, y: 30))
            body.addLine(to: CGPoint(x: 530, y: 70))
            body.addLine(to: CGPoint(x: 615, y: 560))
            body.addLine(to: CGPoint(x: 545, y: 580))
            body.addLine(to: CGPoint(x: 490, y: 240))
            body.addLine(to: CGPoint(x: 495, y: 520))
            body.addLine(to: CGPoint(x: 145, y: 520))
            body.addLine(to: CGPoint(x: 150, y: 240))
            body.addLine(to: CGPoint(x: 95, y: 580))
            body.addLine(to: CGPoint(x: 25, y: 560))
            body.addLine(to: CGPoint(x: 110, y: 70))
            body.close()
            fill(body, color, in: context)
            let zip = UIBezierPath()
            zip.move(to: CGPoint(x: 320, y: 40))
            zip.addLine(to: CGPoint(x: 320, y: 520))
            stroke(zip, alpha: 0.6, width: 4)
            let lapels = UIBezierPath()
            lapels.move(to: CGPoint(x: 230, y: 30))
            lapels.addLine(to: CGPoint(x: 300, y: 180))
            lapels.move(to: CGPoint(x: 410, y: 30))
            lapels.addLine(to: CGPoint(x: 340, y: 180))
            stroke(lapels, alpha: 0.5)
        }
    }

    private static func jeans(color: String) -> UIImage {
        render(CGSize(width: 520, height: 860)) { context in
            let legs = UIBezierPath()
            legs.move(to: CGPoint(x: 90, y: 30))
            legs.addLine(to: CGPoint(x: 430, y: 30))
            legs.addLine(to: CGPoint(x: 445, y: 300))
            legs.addLine(to: CGPoint(x: 500, y: 830))
            legs.addLine(to: CGPoint(x: 300, y: 830))
            legs.addLine(to: CGPoint(x: 262, y: 330))
            legs.addLine(to: CGPoint(x: 220, y: 830))
            legs.addLine(to: CGPoint(x: 20, y: 830))
            legs.addLine(to: CGPoint(x: 75, y: 300))
            legs.close()
            fill(legs, color, in: context)
            let details = UIBezierPath()
            details.move(to: CGPoint(x: 88, y: 75))
            details.addLine(to: CGPoint(x: 432, y: 75))
            details.move(to: CGPoint(x: 262, y: 75))
            details.addLine(to: CGPoint(x: 262, y: 260))
            stroke(details, alpha: 0.35)
        }
    }

    private static func belt(color: String) -> UIImage {
        render(CGSize(width: 520, height: 120)) { context in
            let strap = UIBezierPath(roundedRect: CGRect(x: 10, y: 34, width: 500, height: 52), cornerRadius: 14)
            fill(strap, color, in: context)
            let buckle = UIBezierPath(roundedRect: CGRect(x: 200, y: 14, width: 120, height: 92), cornerRadius: 10)
            UIColor(white: 0.78, alpha: 1).setStroke()
            buckle.lineWidth = 12
            buckle.stroke()
        }
    }

    private static func boot(color: String) -> UIImage {
        render(CGSize(width: 560, height: 480)) { context in
            let shape = UIBezierPath()
            shape.move(to: CGPoint(x: 120, y: 20))
            shape.addLine(to: CGPoint(x: 300, y: 20))
            shape.addLine(to: CGPoint(x: 310, y: 280))
            shape.addQuadCurve(to: CGPoint(x: 540, y: 400), controlPoint: CGPoint(x: 520, y: 300))
            shape.addLine(to: CGPoint(x: 540, y: 430))
            shape.addLine(to: CGPoint(x: 200, y: 430))
            shape.addLine(to: CGPoint(x: 195, y: 460))
            shape.addLine(to: CGPoint(x: 110, y: 460))
            shape.addLine(to: CGPoint(x: 100, y: 410))
            shape.close()
            fill(shape, color, in: context)
            let harness = UIBezierPath(ovalIn: CGRect(x: 150, y: 250, width: 110, height: 80))
            UIColor(white: 0.7, alpha: 1).setStroke()
            harness.lineWidth = 8
            harness.stroke()
        }
    }
}
#endif
