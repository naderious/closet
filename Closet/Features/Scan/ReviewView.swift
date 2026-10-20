import SwiftUI

/// Shows the background-removed piece before its details are filled in.
struct ReviewView: View {
    @Environment(Router.self) private var router
    @Environment(ScanSession.self) private var scan

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "review") {
                IconButton(glyph: .chevronLeft, size: 24, label: "Retake") {
                    router.go(.scan, from: .left)
                }
            }
            .entrance(0.04, from: CGSize(width: 0, height: -12))

            GeometryReader { geometry in
                if let capture = scan.capture {
                    LiftedPreview(
                        original: capture.original,
                        cutout: capture.cutout,
                        showsCutout: capture.lifted && !scan.useOriginal
                    )
                    .frame(width: geometry.size.width * 0.74, height: geometry.size.height * 0.86)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }

            footer
                .padding(.top, 8)
                .padding(.bottom, 20)
                .entrance(0.25, from: CGSize(width: 0, height: 24))
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 18) {
            if let capture = scan.capture {
                if capture.lifted {
                    Button {
                        Haptics.selection()
                        withAnimation(Motion.gentle) { scan.useOriginal.toggle() }
                    } label: {
                        Text(scan.useOriginal ? "remove the background" : "keep the original background")
                            .font(.closet(.regular, 11))
                            .foregroundStyle(Theme.secondaryText)
                            .underline(true, color: Theme.tertiaryText)
                            .contentTransition(.opacity)
                    }
                    .buttonStyle(PressableStyle())
                } else {
                    Text("couldn't lift the background, so the original photo will be used.")
                        .font(.closet(.regular, 11))
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }

            PillButton(title: "continue", isEnabled: scan.capture != nil) {
                scan.commitCapture()
                router.go(.editor, from: .bottom)
            }
        }
    }
}

/// The cutout "lifts" off the photo: it scales in, then a glint sweeps across it.
private struct LiftedPreview: View {
    let original: UIImage
    let cutout: UIImage
    let showsCutout: Bool

    @State private var appeared = false
    @State private var sweep: CGFloat = -0.5

    var body: some View {
        ZStack {
            Image(uiImage: original)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .opacity(showsCutout ? 0 : 1)
                .scaleEffect(showsCutout ? 0.96 : 1)

            Image(uiImage: cutout)
                .resizable()
                .scaledToFit()
                .overlay { glint }
                .shadow(color: Color.white.opacity(0.08), radius: 24)
                .opacity(showsCutout ? 1 : 0)
                .scaleEffect(showsCutout ? 1 : 1.04)
        }
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15)) { appeared = true }
            withAnimation(.easeInOut(duration: 1.25).delay(0.55)) { sweep = 1.3 }
        }
    }

    private var glint: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [Color.white.opacity(0), Color.white.opacity(0.55), Color.white.opacity(0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: geometry.size.width, height: geometry.size.height * 0.4)
            .offset(y: sweep * geometry.size.height - geometry.size.height * 0.2)
            .blendMode(.plusLighter)
        }
        .mask {
            Image(uiImage: cutout)
                .resizable()
                .scaledToFit()
        }
        .allowsHitTesting(false)
    }
}
