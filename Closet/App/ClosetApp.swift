import SwiftUI

@main
struct ClosetApp: App {
    @State private var router: Router
    @State private var store: WardrobeStore
    @State private var outfits = OutfitModel()
    @State private var scan: ScanSession

    init() {
        FontRegistry.shared.activate()
        let router = Router()
        let store = WardrobeStore()
        let scan = ScanSession()
        #if DEBUG
        DebugLaunch.apply(router: router, store: store, scan: scan)
        #endif
        _router = State(initialValue: router)
        _store = State(initialValue: store)
        _scan = State(initialValue: scan)
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
