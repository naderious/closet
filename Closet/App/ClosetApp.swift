import SwiftUI

@main
struct ClosetApp: App {
    @State private var router = Router()
    @State private var store = WardrobeStore()
    @State private var outfits = OutfitModel()
    @State private var scan = ScanSession()

    init() {
        FontRegistry.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .environment(store)
                .environment(outfits)
                .environment(scan)
                .preferredColorScheme(.dark)
                .dynamicTypeSize(.xSmall ... .xxLarge)
        }
    }
}
