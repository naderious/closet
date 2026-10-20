import SwiftUI

struct HomeView: View {
    @Environment(Router.self) private var router
    @Environment(WardrobeStore.self) private var store
    @Environment(OutfitModel.self) private var outfits
    @Environment(ScanSession.self) private var scan

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "closet.", size: TypeScale.wordmark) {
                IconButton(glyph: .wardrobe, size: 30, label: "Wardrobe") {
                    router.go(.wardrobe, from: .left)
                }
            } trailing: {
                IconButton(glyph: .hanger, size: 32, label: "Scan a piece") {
                    scan.reset()
                    router.go(.scan, from: .right)
                }
            }
            .entrance(0.05, from: CGSize(width: 0, height: -12))

            ZStack {
                if store.items.isEmpty {
                    EmptyClosetView()
                        .transition(.opacity)
                } else if let outfit = outfits.current {
                    OutfitCanvas(outfit: outfit) { slot in
                        let swapped = withAnimation(Motion.settle) {
                            outfits.reroll(slot, using: store)
                        }
                        if swapped { Haptics.light() } else { Haptics.warning() }
                    }
                    .id(outfit.id)
                    .opacity(outfits.isClearing ? 0 : 1)
                    .scaleEffect(outfits.isClearing ? 0.96 : 1)
                    .blur(radius: outfits.isClearing ? 8 : 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Group {
                if store.items.isEmpty {
                    PillButton(title: "scan a piece") {
                        scan.reset()
                        router.go(.scan, from: .bottom)
                    }
                } else {
                    PillButton(title: "regenerate", isBusy: outfits.isGenerating) {
                        outfits.regenerate(using: store)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
            .entrance(0.18, from: CGSize(width: 0, height: 24))
        }
        .onAppear { outfits.sync(with: store) }
    }
}

/// Shown until the first piece has been scanned.
struct EmptyClosetView: View {
    var body: some View {
        VStack(spacing: 18) {
            DrawnIcon(glyph: .hanger, size: 70, delay: 0.25, duration: 1.1)
            Text("your closet is empty")
                .displayType(19)
                .foregroundStyle(Theme.text)
                .entrance(0.4)
            Text("scan a few pieces and closet. will start putting outfits together for you.")
                .font(.closet(.regular, 12))
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 250)
                .entrance(0.5)
        }
        .padding(.bottom, 40)
    }
}
