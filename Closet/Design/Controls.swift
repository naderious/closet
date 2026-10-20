import SwiftUI

/// Springs down slightly while pressed.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

/// The white glowing pill ("regenerate", "capture"…). While busy it folds into a
/// circle with a spinning arrow.
struct PillButton: View {
    let title: String
    var isBusy = false
    var isEnabled = true
    let action: () -> Void

    private let height: CGFloat = 42

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            ZStack {
                Text(title)
                    .font(.closet(.bold, TypeScale.button))
                    .tracking(-0.2)
                    .foregroundStyle(Color.black)
                    .fixedSize()
                    .padding(.horizontal, 24)
                    .opacity(isBusy ? 0 : 1)
                    .scaleEffect(isBusy ? 0.55 : 1)
                    .blur(radius: isBusy ? 3 : 0)
                SpinningArrow(isSpinning: isBusy, size: 22)
                    .opacity(isBusy ? 1 : 0)
                    .scaleEffect(isBusy ? 1 : 0.3)
                    .rotationEffect(.degrees(isBusy ? 0 : -120))
            }
            .frame(width: isBusy ? height : nil, height: height)
            .background(Capsule(style: .continuous).fill(Color.white))
            .shadow(color: Color.white.opacity(isEnabled ? 0.30 : 0.1), radius: 12)
            .shadow(color: Color.white.opacity(isEnabled ? 0.10 : 0), radius: 28)
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableStyle())
        .disabled(isBusy || !isEnabled)
        .animation(.spring(response: 0.46, dampingFraction: 0.76), value: isBusy)
        .animation(Motion.snappy, value: isEnabled)
        .accessibilityLabel(isBusy ? "\(title), working" : title)
    }
}

/// A bare icon button with a comfortable tap target.
struct IconButton: View {
    let glyph: IconGlyph
    var size: CGFloat = 26
    var filled = false
    let label: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Icon(glyph: glyph, size: size, filled: filled)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.84))
        .accessibilityLabel(label)
    }
}

/// Large centered title with optional corner buttons, as on every mockup.
struct ScreenHeader<Leading: View, Trailing: View>: View {
    let title: String
    var size: CGFloat = TypeScale.pageTitle
    let leading: Leading
    let trailing: Trailing

    init(
        title: String,
        size: CGFloat = TypeScale.pageTitle,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.size = size
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            Text(title)
                .displayType(size)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, 58)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: 0) {
                leading
                Spacer(minLength: 0)
                trailing
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 72)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, size: CGFloat = TypeScale.pageTitle, @ViewBuilder leading: () -> Leading) {
        self.init(title: title, size: size, leading: leading, trailing: { EmptyView() })
    }
}

/// Fades and slides content in shortly after it appears, so screens assemble
/// themselves instead of popping in.
struct Entrance: ViewModifier {
    let delay: Double
    let offset: CGSize
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(visible ? .zero : offset)
            .onAppear {
                withAnimation(.spring(response: 0.62, dampingFraction: 0.86).delay(delay)) { visible = true }
            }
    }
}

extension View {
    func entrance(_ delay: Double = 0, from offset: CGSize = CGSize(width: 0, height: 16)) -> some View {
        modifier(Entrance(delay: delay, offset: offset))
    }
}

/// Small rounded tag used for categories and quick suggestions.
struct Chip: View {
    let title: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Text(title)
                .font(.closet(isSelected ? .bold : .regular, TypeScale.chip))
                .foregroundStyle(isSelected ? Color.black : Theme.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? Color.white : Color.white.opacity(0.06))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(isSelected ? 0 : 0.18), lineWidth: 1)
                )
                .shadow(color: Color.white.opacity(isSelected ? 0.25 : 0), radius: 8)
        }
        .buttonStyle(PressableStyle(scale: 0.92))
        .animation(Motion.snappy, value: isSelected)
    }
}

/// A brief message that drops in from the top.
struct Toast: View {
    let text: String
    var glyph: IconGlyph = .check

    var body: some View {
        HStack(spacing: 10) {
            DrawnIcon(glyph: glyph, size: 16, color: .black, delay: 0.15, duration: 0.45)
            Text(text)
                .font(.closet(.bold, 12))
                .foregroundStyle(Color.black)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Capsule(style: .continuous).fill(Color.white))
        .shadow(color: Color.white.opacity(0.3), radius: 14)
    }
}
