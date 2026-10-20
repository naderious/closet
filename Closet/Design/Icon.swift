import SwiftUI

/// Renders an `IconGlyph` as a SwiftUI shape scaled from its 24×24 grid.
struct IconShape: Shape {
    let glyph: IconGlyph

    private static let commands: [IconGlyph: [PathCommand]] = Dictionary(
        uniqueKeysWithValues: IconGlyph.allCases.map { ($0, SVGPath.parse($0.pathData)) }
    )

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        let dx = rect.minX + (rect.width - 24 * scale) / 2
        let dy = rect.minY + (rect.height - 24 * scale) / 2
        func map(_ point: CGPoint) -> CGPoint {
            CGPoint(x: dx + point.x * scale, y: dy + point.y * scale)
        }

        var path = Path()
        for command in IconShape.commands[glyph] ?? [] {
            switch command {
            case .move(let point):
                path.move(to: map(point))
            case .line(let point):
                path.addLine(to: map(point))
            case .quad(let point, let control):
                path.addQuadCurve(to: map(point), control: map(control))
            case .cubic(let point, let control1, let control2):
                path.addCurve(to: map(point), control1: map(control1), control2: map(control2))
            case .close:
                path.closeSubpath()
            }
        }
        return path
    }
}

/// A line icon with the app's shared stroke weight. `progress` draws it on.
struct Icon: View {
    let glyph: IconGlyph
    var size: CGFloat = 26
    var color: Color = .white
    var filled = false
    var progress: CGFloat = 1

    var body: some View {
        let lineWidth = max(1.3, size * 0.068)
        ZStack {
            IconShape(glyph: glyph)
                .fill(color)
                .opacity(filled ? 1 : 0)
                .scaleEffect(filled ? 1 : 0.5)
            IconShape(glyph: glyph)
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}

/// An icon that draws itself in when it first appears.
struct DrawnIcon: View {
    let glyph: IconGlyph
    var size: CGFloat = 26
    var color: Color = .white
    var delay: Double = 0
    var duration: Double = 0.7
    @State private var progress: CGFloat = 0

    var body: some View {
        Icon(glyph: glyph, size: size, color: color, progress: progress)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).delay(delay)) { progress = 1 }
            }
    }
}

/// The circular arrow used while something is loading.
struct SpinningArrow: View {
    var isSpinning: Bool
    var size: CGFloat = 22
    var color: Color = .black
    var period: Double = 0.85

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !isSpinning)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let angle = isSpinning ? time.truncatingRemainder(dividingBy: period) / period * 360 : 0
            Icon(glyph: .refresh, size: size, color: color)
                .rotationEffect(.degrees(angle))
        }
    }
}
