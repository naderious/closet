import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// A piece to lay out on the outfit canvas.
struct LayoutPiece {
    var id: UUID
    var slot: OutfitSlot
    /// Width / height of the image.
    var aspect: Double
    var edges: EdgeProfile?
    var label: String
}

struct PlacedPiece: Identifiable, Equatable {
    var id: UUID
    var slot: OutfitSlot
    var frame: CGRect
    var zIndex: Double
}

enum CalloutSide: Equatable {
    case leading, trailing
}

/// A name label joined to its garment by a line with rounded bends.
struct Callout: Identifiable, Equatable {
    var id: UUID
    var slot: OutfitSlot
    /// Starts at the garment edge and ends under (or over) the label.
    var points: [CGPoint]
    var cornerRadius: CGFloat
    var side: CalloutSide
    var textAbove: Bool
    var text: String
    var textWidth: CGFloat

    var anchor: CGPoint { points.last ?? .zero }
}

struct OutfitLayoutResult: Equatable {
    var pieces: [PlacedPiece]
    var callouts: [Callout]

    static let empty = OutfitLayoutResult(pieces: [], callouts: [])
}

/// Arranges garments like a flat lay: shirt over trousers, belt at the waist,
/// shoes over the hem, plus the callout lines that name each piece.
struct OutfitLayout {
    var labelFontSize: CGFloat = 10.5
    var margin: CGFloat = 14
    /// Average glyph advance as a fraction of the font size, for estimating label wrapping.
    var averageGlyphWidth: CGFloat = 0.58

    static let stackingOrder: [OutfitSlot] = [.outer, .bottom, .top, .belt, .shoes]

    func layout(_ input: [LayoutPiece], in size: CGSize) -> OutfitLayoutResult {
        let width = size.width
        let height = size.height
        guard width > 40, height > 40, !input.isEmpty else { return .empty }

        var bySlot: [OutfitSlot: LayoutPiece] = [:]
        for piece in input where bySlot[piece.slot] == nil {
            bySlot[piece.slot] = piece
        }
        let sideBySide = bySlot[.top] != nil && bySlot[.outer] != nil
        let natural = naturalFrames(bySlot, unit: width, sideBySide: sideBySide)
        guard let bounds = OutfitLayout.union(Array(natural.values)), bounds.width > 0, bounds.height > 0 else {
            return .empty
        }

        // Scale the arrangement into the canvas, leaving room for labels above and below.
        let labelBand = labelFontSize * 3.6
        let widthShare: CGFloat = sideBySide ? 0.72 : 0.62
        let scale = min(1.15, (height - labelBand * 2) / bounds.height, width * widthShare / bounds.width)
        func place(_ rect: CGRect) -> CGRect {
            CGRect(
                x: width / 2 + (rect.minX - bounds.midX) * scale,
                y: height / 2 + (rect.minY - bounds.midY) * scale,
                width: rect.width * scale,
                height: rect.height * scale
            )
        }
        let frames = natural.mapValues(place)

        let pieces = OutfitLayout.stackingOrder.enumerated().compactMap { index, slot -> PlacedPiece? in
            guard let piece = bySlot[slot], let frame = frames[slot] else { return nil }
            return PlacedPiece(id: piece.id, slot: slot, frame: frame, zIndex: Double(index))
        }

        let callouts = makeCallouts(
            bySlot, frames: frames, size: size, sideBySide: sideBySide, unit: min(scale, 1) * width / 375
        )
        return OutfitLayoutResult(pieces: pieces, callouts: callouts)
    }

    // MARK: Garments

    private func naturalFrames(_ bySlot: [OutfitSlot: LayoutPiece], unit: CGFloat, sideBySide: Bool) -> [OutfitSlot: CGRect] {
        var frames: [OutfitSlot: CGRect] = [:]

        if sideBySide, let top = bySlot[.top], let outer = bySlot[.outer] {
            let outerSize = OutfitLayout.fit(outer.aspect, in: CGSize(width: 0.40 * unit, height: 0.46 * unit))
            let topSize = OutfitLayout.fit(top.aspect, in: CGSize(width: 0.36 * unit, height: 0.36 * unit))
            let overlap = 0.3 * min(outerSize.width, topSize.width)
            let rowWidth = outerSize.width + topSize.width - overlap
            let outerRect = CGRect(x: -rowWidth / 2, y: 0, width: outerSize.width, height: outerSize.height)
            frames[.outer] = outerRect
            frames[.top] = CGRect(
                x: outerRect.maxX - overlap, y: outerSize.height * 0.1, width: topSize.width, height: topSize.height
            )
        } else if let upper = bySlot[.top] ?? bySlot[.outer] {
            let size = OutfitLayout.fit(upper.aspect, in: CGSize(width: 0.45 * unit, height: 0.43 * unit))
            frames[upper.slot] = CGRect(x: -size.width / 2, y: 0, width: size.width, height: size.height)
        }

        if let bottom = bySlot[.bottom] {
            let size = OutfitLayout.fit(bottom.aspect, in: CGSize(width: 0.42 * unit, height: 0.66 * unit))
            let upper = frames[.top] ?? frames[.outer]
            // The shirt hem overlaps the waistband slightly.
            let y = upper.map { $0.maxY - $0.height * 0.05 } ?? 0
            frames[.bottom] = CGRect(x: -size.width / 2, y: y, width: size.width, height: size.height)
        }

        if let belt = bySlot[.belt] {
            if let bottomRect = frames[.bottom], let bottom = bySlot[.bottom] {
                let waistLeading = CGFloat(bottom.edges?.leadingEdge(at: 0.01) ?? 0.05)
                let waistTrailing = CGFloat(bottom.edges?.trailingEdge(at: 0.01) ?? 0.95)
                let waistWidth = max(0.3, waistTrailing - waistLeading) * bottomRect.width
                let waistMid = bottomRect.minX + (waistLeading + waistTrailing) / 2 * bottomRect.width
                let size = OutfitLayout.fit(belt.aspect, in: CGSize(width: waistWidth * 0.68, height: bottomRect.height * 0.1))
                frames[.belt] = CGRect(
                    x: waistMid - size.width / 2, y: bottomRect.minY - size.height * 0.25,
                    width: size.width, height: size.height
                )
            } else {
                let size = OutfitLayout.fit(belt.aspect, in: CGSize(width: 0.32 * unit, height: 0.12 * unit))
                let y = frames.values.map(\.maxY).max().map { $0 + 0.04 * unit } ?? 0
                frames[.belt] = CGRect(x: -size.width / 2, y: y, width: size.width, height: size.height)
            }
        }

        if let shoes = bySlot[.shoes] {
            if let bottomRect = frames[.bottom] {
                let size = OutfitLayout.fit(
                    shoes.aspect, in: CGSize(width: bottomRect.width * 0.58, height: bottomRect.height * 0.3)
                )
                // The shoes straddle the hem, just like the flat lay.
                let center = CGPoint(
                    x: bottomRect.midX + bottomRect.width * 0.03,
                    y: bottomRect.maxY + bottomRect.height * 0.015
                )
                frames[.shoes] = CGRect(
                    x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height
                )
            } else {
                let size = OutfitLayout.fit(shoes.aspect, in: CGSize(width: 0.3 * unit, height: 0.24 * unit))
                let y = frames.values.map(\.maxY).max().map { $0 + 0.05 * unit } ?? 0
                frames[.shoes] = CGRect(x: -size.width / 2, y: y, width: size.width, height: size.height)
            }
        }

        return frames
    }

    // MARK: Callouts

    private struct CalloutSpec {
        var side: CalloutSide
        var y: Double
        var up: Bool
        var offset: CGFloat
    }

    private func spec(for slot: OutfitSlot, sideBySide: Bool) -> CalloutSpec {
        if sideBySide {
            switch slot {
            case .outer: return CalloutSpec(side: .leading, y: 0.42, up: true, offset: 50)
            case .top: return CalloutSpec(side: .trailing, y: 0.4, up: true, offset: 44)
            case .belt: return CalloutSpec(side: .trailing, y: 0.5, up: true, offset: 22)
            case .bottom: return CalloutSpec(side: .trailing, y: 0.22, up: false, offset: 46)
            case .shoes: return CalloutSpec(side: .leading, y: 0.72, up: false, offset: 28)
            }
        }
        switch slot {
        case .outer, .top: return CalloutSpec(side: .leading, y: 0.5, up: true, offset: 50)
        case .belt: return CalloutSpec(side: .trailing, y: 0.5, up: true, offset: 34)
        case .bottom: return CalloutSpec(side: .trailing, y: 0.19, up: false, offset: 48)
        case .shoes: return CalloutSpec(side: .leading, y: 0.75, up: false, offset: 27)
        }
    }

    private struct Draft {
        var piece: LayoutPiece
        var spec: CalloutSpec
        var start: CGPoint
        var lineY: CGFloat
        var textHeight: CGFloat = 0
        var textWidth: CGFloat = 0

        var band: ClosedRange<CGFloat> {
            spec.up ? (lineY - 4 - textHeight)...lineY : lineY...(lineY + 4 + textHeight)
        }
    }

    private func makeCallouts(
        _ bySlot: [OutfitSlot: LayoutPiece], frames: [OutfitSlot: CGRect], size: CGSize, sideBySide: Bool, unit: CGFloat
    ) -> [Callout] {
        let width = size.width
        let height = size.height
        let gap: CGFloat = 5 * max(unit, 0.6)

        var drafts: [Draft] = []
        for slot in OutfitLayout.stackingOrder {
            guard let piece = bySlot[slot], let frame = frames[slot] else { continue }
            let spec = spec(for: slot, sideBySide: sideBySide)
            let edge: Double
            switch spec.side {
            case .leading: edge = piece.edges?.leadingEdge(at: spec.y) ?? 0.06
            case .trailing: edge = piece.edges?.trailingEdge(at: spec.y) ?? 0.94
            }
            let start = CGPoint(
                x: frame.minX + CGFloat(edge) * frame.width + (spec.side == .leading ? -gap : gap),
                y: frame.minY + CGFloat(spec.y) * frame.height
            )
            let offset = spec.offset * unit
            drafts.append(Draft(piece: piece, spec: spec, start: start, lineY: start.y + (spec.up ? -offset : offset)))
        }

        // Each side shares one vertical "trunk" so the bends line up.
        let minRun = 22 * unit
        let minFinal = 26 * unit
        var trunks: [CalloutSide: CGFloat] = [:]
        let leadingStarts = drafts.filter { $0.spec.side == .leading }.map(\.start.x)
        let trailingStarts = drafts.filter { $0.spec.side == .trailing }.map(\.start.x)
        if let minX = leadingStarts.min() {
            trunks[.leading] = max(margin + minFinal, minX - minRun)
        }
        if let maxX = trailingStarts.max() {
            trunks[.trailing] = min(width - margin - minFinal, maxX + minRun)
        }

        // Size the text blocks: a label may run past its trunk up to the garments.
        let group = OutfitLayout.union(Array(frames.values)) ?? CGRect(x: width / 2, y: 0, width: 0, height: 0)
        for index in drafts.indices {
            let side = drafts[index].spec.side
            let trunk = trunks[side] ?? width / 2
            let room = side == .leading ? trunk - margin : width - margin - trunk
            let clearance = side == .leading ? group.minX - margin - 6 : width - margin - group.maxX - 6
            let textWidth = max(room + 24 * unit, clearance).clamped(to: 70...(width * 0.45))
            let text = drafts[index].piece.label
            let estimated = CGFloat(text.count) * labelFontSize * averageGlyphWidth
            let lines = min(2, max(1, Int((estimated / textWidth).rounded(.up))))
            drafts[index].textWidth = textWidth
            drafts[index].textHeight = CGFloat(lines) * labelFontSize * 1.3
        }

        // Keep labels on the same side from overlapping, and inside the canvas.
        for side in [CalloutSide.leading, .trailing] {
            let indices = drafts.indices
                .filter { drafts[$0].spec.side == side }
                .sorted { drafts[$0].band.lowerBound < drafts[$1].band.lowerBound }
            guard !indices.isEmpty else { continue }
            for (position, index) in indices.enumerated() where position > 0 {
                let previous = drafts[indices[position - 1]].band
                let current = drafts[index].band
                let overlap = previous.upperBound + 10 - current.lowerBound
                if overlap > 0 { drafts[index].lineY += overlap }
            }
            if let last = indices.last {
                let overflow = drafts[last].band.upperBound - height
                if overflow > 0 { indices.forEach { drafts[$0].lineY -= overflow } }
            }
            if let first = indices.first {
                let underflow = -drafts[first].band.lowerBound
                if underflow > 0 { indices.forEach { drafts[$0].lineY += underflow } }
            }
        }

        let baseRadius = 10 * max(unit, 0.6)
        return drafts.map { draft in
            let side = draft.spec.side
            let trunk = trunks[side] ?? draft.start.x
            let endX = side == .leading ? margin : width - margin
            let dy = abs(draft.lineY - draft.start.y)
            let points: [CGPoint]
            var radius = baseRadius
            if dy < 3 {
                points = [draft.start, CGPoint(x: endX, y: draft.start.y)]
            } else {
                radius = min(baseRadius, dy / 2)
                points = [
                    draft.start,
                    CGPoint(x: trunk, y: draft.start.y),
                    CGPoint(x: trunk, y: draft.lineY),
                    CGPoint(x: endX, y: draft.lineY),
                ]
            }
            return Callout(
                id: draft.piece.id,
                slot: draft.piece.slot,
                points: points,
                cornerRadius: radius,
                side: side,
                textAbove: draft.spec.up,
                text: draft.piece.label,
                textWidth: draft.textWidth
            )
        }
    }

    // MARK: Helpers

    static func fit(_ aspect: Double, in box: CGSize) -> CGSize {
        let ratio = CGFloat(aspect > 0.05 && aspect.isFinite ? aspect : 1)
        guard box.width > 0, box.height > 0 else { return .zero }
        if box.width / box.height > ratio {
            return CGSize(width: box.height * ratio, height: box.height)
        }
        return CGSize(width: box.width, height: box.width / ratio)
    }

    static func union(_ rects: [CGRect]) -> CGRect? {
        guard let first = rects.first else { return nil }
        var minX = first.minX, minY = first.minY, maxX = first.maxX, maxY = first.maxY
        for rect in rects.dropFirst() {
            minX = min(minX, rect.minX)
            minY = min(minY, rect.minY)
            maxX = max(maxX, rect.maxX)
            maxY = max(maxY, rect.maxY)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
