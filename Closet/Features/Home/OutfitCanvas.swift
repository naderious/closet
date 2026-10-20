import SwiftUI

/// Lays out the outfit as a flat lay and names each piece with an animated callout.
struct OutfitCanvas: View {
    let outfit: Outfit
    let onTapPiece: (OutfitSlot) -> Void

    @Environment(WardrobeStore.self) private var store

    var body: some View {
        GeometryReader { geometry in
            let items = pieces
            let layout = OutfitLayout(labelFontSize: TypeScale.callout).layout(
                items.map { LayoutPiece(id: $0.item.id, slot: $0.slot, aspect: $0.item.imageAspect, edges: $0.item.edgeProfile, label: $0.item.displayName.lowercased()) },
                in: geometry.size
            )
            let lookup = Dictionary(items.map { ($0.item.id, $0.item) }, uniquingKeysWith: { first, _ in first })
            let signature = outfit.itemIDs.map(\.uuidString).joined()

            ZStack(alignment: .topLeading) {
                ForEach(Array(layout.pieces.enumerated()), id: \.element.id) { index, placed in
                    if let item = lookup[placed.id] {
                        GarmentView(item: item, frame: placed.frame, delay: 0.06 + Double(index) * 0.08) {
                            onTapPiece(placed.slot)
                        }
                        .zIndex(placed.zIndex)
                    }
                }

                ForEach(Array(layout.callouts.enumerated()), id: \.element.id) { index, callout in
                    CalloutView(callout: callout, delay: 0.5 + Double(index) * 0.11)
                        .id("\(callout.id.uuidString)-\(signature)")
                        .zIndex(20)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
    }

    private var pieces: [(slot: OutfitSlot, item: ClothingItem)] {
        OutfitSlot.allCases.compactMap { slot in
            guard let item = store.item(outfit[slot]) else { return nil }
            return (slot, item)
        }
    }
}

/// One garment cutout. Drops into place on appear; tap to swap it.
private struct GarmentView: View {
    let item: ClothingItem
    let frame: CGRect
    let delay: Double
    let onTap: () -> Void

    @State private var shown = false

    var body: some View {
        Button(action: onTap) {
            StoredImage(fileName: item.imageFileName, maxPixel: 1100)
                .frame(width: frame.width, height: frame.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.96))
        .scaleEffect(shown ? 1 : 0.9)
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : -18)
        .position(x: frame.midX, y: frame.midY)
        .animation(Motion.settle, value: frame)
        .transition(.opacity.combined(with: .scale(scale: 0.92)))
        .onAppear {
            withAnimation(Motion.settle.delay(delay)) { shown = true }
        }
        .accessibilityLabel(item.displayName)
        .accessibilityHint("Double tap to swap this piece")
    }
}

/// The leader line, drawn from the garment outwards, followed by the piece's name.
private struct CalloutView: View {
    let callout: Callout
    let delay: Double

    @State private var progress: CGFloat = 0
    @State private var labelShown = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            CalloutLine(points: callout.points, radius: callout.cornerRadius)
                .trim(from: 0, to: progress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: Theme.line, lineCap: .round, lineJoin: .round))

            Color.clear
                .frame(width: 1, height: 1)
                .overlay(alignment: labelAlignment) {
                    Text(callout.text)
                        .font(.closet(.regular, TypeScale.callout))
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(callout.side == .leading ? .leading : .trailing)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: callout.textWidth, alignment: callout.side == .leading ? .leading : .trailing)
                        .padding(callout.textAbove ? .bottom : .top, 5)
                        .opacity(labelShown ? 1 : 0)
                        .offset(x: labelShown ? 0 : (callout.side == .leading ? 8 : -8))
                        .blur(radius: labelShown ? 0 : 2)
                }
                .position(callout.anchor)
        }
        .onAppear {
            withAnimation(.timingCurve(0.55, 0, 0.25, 1, duration: 0.6).delay(delay)) { progress = 1 }
            withAnimation(.easeOut(duration: 0.45).delay(delay + 0.45)) { labelShown = true }
        }
    }

    private var labelAlignment: Alignment {
        switch (callout.side, callout.textAbove) {
        case (.leading, true): return .bottomLeading
        case (.leading, false): return .topLeading
        case (.trailing, true): return .bottomTrailing
        case (.trailing, false): return .topTrailing
        }
    }
}

/// A polyline with rounded bends.
struct CalloutLine: Shape {
    let points: [CGPoint]
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first, points.count > 1 else { return path }
        path.move(to: first)
        if points.count > 2 {
            for index in 1..<(points.count - 1) {
                path.addArc(tangent1End: points[index], tangent2End: points[index + 1], radius: radius)
            }
        }
        path.addLine(to: points[points.count - 1])
        return path
    }
}
