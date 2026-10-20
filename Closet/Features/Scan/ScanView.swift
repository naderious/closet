import PhotosUI
import SwiftUI

struct ScanView: View {
    @Environment(Router.self) private var router
    @Environment(ScanSession.self) private var scan

    @State private var cameraState: CameraState = .idle
    @State private var isProcessing = false
    @State private var flash = false
    @State private var pickerItem: PhotosPickerItem?

    private let camera = CameraController.shared

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "scan") {
                IconButton(glyph: .chevronLeft, size: 24, label: "Back") { goBack() }
            } trailing: {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Icon(glyph: .photo, size: 24)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle(scale: 0.84))
                .disabled(isProcessing)
                .accessibilityLabel("Choose from your photos")
            }
            .entrance(0.04, from: CGSize(width: 0, height: -12))

            GeometryReader { geometry in
                let width = min(geometry.size.width * 0.66, (geometry.size.height - 24) * 0.75)
                viewfinder(width: max(width, 120))
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .entrance(0.12, from: CGSize(width: 40, height: 0))

            PillButton(title: "capture", isBusy: isProcessing, isEnabled: cameraState == .running) {
                capture()
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
            .entrance(0.2, from: CGSize(width: 0, height: 24))
        }
        .onAppear {
            camera.start { state in
                withAnimation(Motion.gentle) { cameraState = state }
            }
        }
        .onDisappear { camera.stop() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            importPhoto(item)
        }
    }

    // MARK: Viewfinder

    private func viewfinder(width: CGFloat) -> some View {
        let height = width * 4 / 3
        let inset: CGFloat = 9
        return ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black)
                .shadow(color: Color.white.opacity(0.2), radius: 16)
                .shadow(color: Color.white.opacity(0.06), radius: 36)

            ZStack {
                Color.black
                switch cameraState {
                case .running:
                    CameraPreview(session: camera.session)
                        .transition(.opacity)
                case .idle:
                    SpinningArrow(isSpinning: true, size: 26, color: Theme.secondaryText)
                case .denied:
                    CameraMessage(
                        text: "closet. needs the camera to scan your clothes.",
                        actionTitle: "open settings"
                    ) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                case .unavailable:
                    CameraMessage(text: "no camera available here. pick a photo instead with the icon above.")
                }

                Color.white
                    .opacity(flash ? 0.85 : 0)
                    .allowsHitTesting(false)

                if isProcessing {
                    LiftingOverlay()
                        .transition(.opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(inset)
        }
        .frame(width: width + inset * 2, height: height + inset * 2)
        .animation(Motion.gentle, value: isProcessing)
    }

    // MARK: Actions

    private func goBack() {
        if scan.returnsToEditor {
            scan.returnsToEditor = false
            router.go(.editor, from: .left)
        } else {
            scan.reset()
            router.go(.home, from: .left)
        }
    }

    private func capture() {
        guard !isProcessing else { return }
        isProcessing = true
        Haptics.rigid()
        withAnimation(.easeOut(duration: 0.07)) { flash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            withAnimation(.easeOut(duration: 0.5)) { flash = false }
        }
        Task { @MainActor in
            do {
                let photo = try await camera.capture()
                await process(photo)
            } catch {
                isProcessing = false
                Haptics.warning()
            }
        }
    }

    private func importPhoto(_ item: PhotosPickerItem) {
        isProcessing = true
        Task { @MainActor in
            let data = try? await item.loadTransferable(type: Data.self)
            pickerItem = nil
            guard let data, let image = UIImage(data: data) else {
                isProcessing = false
                Haptics.warning()
                return
            }
            await process(image)
        }
    }

    @MainActor
    private func process(_ photo: UIImage) async {
        async let lifted = BackgroundRemover.lift(photo)
        async let guess = ClothingClassifier.suggestCategory(for: photo)
        let result = await lifted
        let category = await guess

        scan.capture = result
        scan.useOriginal = false
        if scan.draft == nil { scan.suggestedCategory = category }
        Haptics.success()
        router.go(.review, from: .bottom)
    }
}

extension CameraController {
    static let shared = CameraController()
}

/// A slow light sweep over the frozen frame while the background is removed.
private struct LiftingOverlay: View {
    @State private var phase: CGFloat = -0.4

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.35)
                LinearGradient(
                    colors: [Color.white.opacity(0), Color.white.opacity(0.28), Color.white.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: geometry.size.height * 0.35)
                .offset(y: phase * geometry.size.height)
                .blendMode(.plusLighter)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { phase = 0.6 }
        }
        .allowsHitTesting(false)
    }
}

private struct CameraMessage: View {
    let text: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Icon(glyph: .camera, size: 34, color: Theme.secondaryText)
            Text(text)
                .font(.closet(.regular, 12))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            if let actionTitle, let action {
                Chip(title: actionTitle, action: action)
            }
        }
        .padding(24)
    }
}
