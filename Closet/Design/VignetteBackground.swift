import SwiftUI

/// The black backdrop with a soft, stadium-shaped glow seen behind every screen.
struct VignetteBackground: View {
    var body: some View {
        ZStack {
            Theme.background
            Color(white: 0.056)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0), location: 0),
                            .init(color: .black.opacity(0.22), location: 0.07),
                            .init(color: .black.opacity(0.5), location: 0.14),
                            .init(color: .black.opacity(0.8), location: 0.21),
                            .init(color: .black, location: 0.29),
                            .init(color: .black, location: 0.71),
                            .init(color: .black.opacity(0.8), location: 0.79),
                            .init(color: .black.opacity(0.5), location: 0.86),
                            .init(color: .black.opacity(0.22), location: 0.93),
                            .init(color: .black.opacity(0), location: 1),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0), location: 0.08),
                            .init(color: .black.opacity(0.45), location: 0.14),
                            .init(color: .black, location: 0.21),
                            .init(color: .black, location: 0.8),
                            .init(color: .black.opacity(0.45), location: 0.87),
                            .init(color: .black.opacity(0), location: 0.93),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            RadialGradient(
                colors: [Color.white.opacity(0.018), Color.white.opacity(0)],
                center: .center,
                startRadius: 0,
                endRadius: 420
            )
        }
        .drawingGroup()
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
