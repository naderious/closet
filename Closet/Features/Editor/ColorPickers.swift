import SwiftUI

/// The photo with an eyedropper: drag over the garment to sample its color.
struct EyedropperImage: View {
    let image: UIImage
    let sampler: PixelSampler?
    let isActive: Bool
    @Binding var color: RGBColor

    @State private var touch: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            let fitted = EyedropperImage.fittedRect(for: image.size, in: geometry.size)
            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)

                if let touch {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                        .position(touch)
                    Loupe(color: color)
                        .position(x: touch.x, y: max(28, touch.y - 62))
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard fitted.width > 0, fitted.height > 0 else { return }
                        let point = value.location
                        let normalized = CGPoint(
                            x: (point.x - fitted.minX) / fitted.width,
                            y: (point.y - fitted.minY) / fitted.height
                        )
                        guard (0...1).contains(normalized.x), (0...1).contains(normalized.y) else { return }
                        if touch == nil {
                            Haptics.selection()
                            withAnimation(Motion.snappy) { touch = point }
                        } else {
                            touch = point
                        }
                        if let sampled = sampler?.color(at: normalized) {
                            color = sampled
                        }
                    }
                    .onEnded { _ in
                        withAnimation(Motion.snappy) { touch = nil }
                    },
                including: isActive ? .all : .subviews
            )
        }
    }

    static func fittedRect(for imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }
}

private struct Loupe: View {
    let color: RGBColor

    var body: some View {
        Circle()
            .fill(Color(color))
            .frame(width: 46, height: 46)
            .overlay(Circle().strokeBorder(Color.white, lineWidth: 3))
            .shadow(color: Color.black.opacity(0.5), radius: 8, y: 3)
    }
}

/// Hue/saturation wheel with a brightness slider.
struct ColorWheel: View {
    @Binding var color: RGBColor

    @State private var hue: Double
    @State private var saturation: Double
    @State private var brightness: Double

    private static let hues: [Color] = stride(from: 0.0, through: 1.0, by: 1.0 / 12).map {
        Color(hue: $0, saturation: 1, brightness: 1)
    }

    init(color: Binding<RGBColor>) {
        _color = color
        let hsb = color.wrappedValue.hsb
        _hue = State(initialValue: hsb.hue)
        _saturation = State(initialValue: hsb.saturation)
        _brightness = State(initialValue: max(0.04, hsb.brightness))
    }

    var body: some View {
        VStack(spacing: 22) {
            GeometryReader { geometry in
                let diameter = min(geometry.size.width, geometry.size.height)
                let radius = diameter / 2
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

                ZStack {
                    Circle().fill(AngularGradient(colors: ColorWheel.hues, center: .center))
                    Circle().fill(
                        RadialGradient(colors: [Color.white, Color.white.opacity(0)], center: .center, startRadius: 0, endRadius: radius)
                    )
                    Circle().fill(Color.black.opacity(1 - brightness))
                    Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                }
                .frame(width: diameter, height: diameter)
                .position(center)
                .overlay {
                    Circle()
                        .fill(Color(hue: hue, saturation: saturation, brightness: brightness))
                        .frame(width: 28, height: 28)
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 3))
                        .shadow(color: Color.black.opacity(0.45), radius: 4, y: 2)
                        .position(thumbPosition(center: center, radius: radius))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { value in
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        var angle = atan2(dy, dx)
                        if angle < 0 { angle += 2 * .pi }
                        hue = Double(angle / (2 * .pi))
                        saturation = Double(min(1, sqrt(dx * dx + dy * dy) / max(radius, 1)))
                        commit()
                    }
                )
            }

            BrightnessSlider(value: $brightness, hue: hue, saturation: saturation)
                .frame(height: 30)
        }
        .onChange(of: brightness) { _, _ in commit() }
    }

    private func thumbPosition(center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = CGFloat(hue) * 2 * .pi
        let distance = CGFloat(saturation) * radius
        return CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)
    }

    private func commit() {
        color = RGBColor(hue: hue, saturation: saturation, brightness: brightness)
    }
}

private struct BrightnessSlider: View {
    @Binding var value: Double
    let hue: Double
    let saturation: Double

    private let knob: CGFloat = 26

    var body: some View {
        GeometryReader { geometry in
            let track = max(1, geometry.size.width - knob)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.black, Color(hue: hue, saturation: saturation, brightness: 1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                Circle()
                    .fill(Color(hue: hue, saturation: saturation, brightness: value))
                    .frame(width: knob, height: knob)
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 3))
                    .shadow(color: Color.black.opacity(0.4), radius: 3, y: 1)
                    .offset(x: CGFloat(value) * track)
            }
            .frame(height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { gesture in
                    value = Double(((gesture.location.x - knob / 2) / track).clamped(to: 0...1))
                }
            )
        }
        .accessibilityElement()
        .accessibilityLabel("Brightness")
        .accessibilityValue("\(Int(value * 100)) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(1, value + 0.05)
            case .decrement: value = max(0, value - 0.05)
            @unknown default: break
            }
        }
    }
}
