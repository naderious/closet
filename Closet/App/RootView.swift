import SwiftUI

struct RootView: View {
    @Environment(Router.self) private var router

    var body: some View {
        ZStack {
            VignetteBackground()

            ZStack {
                screen
                    .id(router.route)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: router.insertionEdge).combined(with: .opacity),
                            removal: .move(edge: router.insertionEdge.opposite).combined(with: .opacity)
                        )
                    )
            }

            if let toast = router.toast {
                VStack {
                    Toast(text: toast)
                        .padding(.top, 8)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
                .allowsHitTesting(false)
            }
        }
        .tint(.white)
    }

    @ViewBuilder
    private var screen: some View {
        switch router.route {
        case .home: HomeView()
        case .wardrobe: WardrobeView()
        case .scan: ScanView()
        case .review: ReviewView()
        case .editor: ItemEditorView()
        }
    }
}
