import Observation
import SwiftUI

enum Route: Hashable {
    case home, wardrobe, scan, review, editor
}

/// Where the tapped control sits. Pages slide in from that side:
/// left → from the left, right → from the right, top → up from the bottom,
/// bottom → down from the top.
enum Placement {
    case left, right, top, bottom

    var insertionEdge: Edge {
        switch self {
        case .left: return .leading
        case .right: return .trailing
        case .top: return .bottom
        case .bottom: return .top
        }
    }
}

@Observable
final class Router {
    private(set) var route: Route = .home
    private(set) var insertionEdge: Edge = .trailing
    /// A short confirmation shown at the top of the next screen.
    var toast: String?
    /// Which wardrobe sections are unfolded, remembered between visits.
    var expandedSections: Set<String> = []

    func go(_ destination: Route, from placement: Placement) {
        guard destination != route else { return }
        // Update the edge first so the outgoing page picks up the matching
        // removal transition, then change the page on the next pass.
        insertionEdge = placement.insertionEdge
        DispatchQueue.main.async {
            withAnimation(Motion.page) {
                self.route = destination
            }
        }
    }

    /// Switches screens without a transition (used for launch shortcuts).
    func jump(to destination: Route) {
        route = destination
    }

    func showToast(_ message: String) {
        withAnimation(Motion.snappy) { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if self.toast == message {
                withAnimation(Motion.gentle) { self.toast = nil }
            }
        }
    }
}
