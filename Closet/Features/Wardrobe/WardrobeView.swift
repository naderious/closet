import SwiftUI

enum WardrobeSection: Hashable, Identifiable {
    case favorites
    case category(ClothingCategory)

    static var all: [WardrobeSection] {
        [.favorites] + ClothingCategory.allCases.map { .category($0) }
    }

    var id: String {
        switch self {
        case .favorites: return "favorites"
        case .category(let category): return category.rawValue
        }
    }

    var title: String {
        switch self {
        case .favorites: return "favorites"
        case .category(let category): return category.title
        }
    }

    var style: SectionStyle {
        switch self {
        case .favorites: return .favorites
        case .category(let category): return category.style
        }
    }
}

struct WardrobeView: View {
    @Environment(Router.self) private var router
    @Environment(WardrobeStore.self) private var store
    @Environment(ScanSession.self) private var scan

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader(title: "wardrobe") {
                IconButton(glyph: .chevronLeft, size: 24, label: "Back") {
                    router.go(.home, from: .left)
                }
            }
            .entrance(0.04, from: CGSize(width: 0, height: -12))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    ForEach(Array(WardrobeSection.all.enumerated()), id: \.element.id) { index, section in
                        sectionView(section)
                            .entrance(0.08 + Double(index) * 0.05, from: CGSize(width: -24, height: 0))
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 10)
                .padding(.bottom, 48)
            }
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0), location: 0),
                        .init(color: .black, location: 0.035),
                        .init(color: .black, location: 0.94),
                        .init(color: .black.opacity(0), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
    }

    @ViewBuilder
    private func sectionView(_ section: WardrobeSection) -> some View {
        let items = items(for: section)
        let isExpanded = router.expandedSections.contains(section.id)

        VStack(spacing: 10) {
            SectionCard(
                title: section.title,
                count: items.count,
                meta: meta(for: section, items: items),
                style: section.style,
                isExpanded: isExpanded
            ) {
                withAnimation(Motion.snappy) {
                    if isExpanded {
                        router.expandedSections.remove(section.id)
                    } else {
                        router.expandedSections.insert(section.id)
                    }
                }
            }
            .zIndex(1)

            if isExpanded {
                if items.isEmpty {
                    EmptySectionRow(section: section)
                        .transition(rowTransition(index: 0))
                } else {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        ItemRow(
                            item: item,
                            style: item.category.style,
                            onEdit: {
                                scan.beginEditing(item)
                                router.go(.editor, from: .right)
                            },
                            onFavorite: {
                                withAnimation(Motion.snappy) { store.toggleFavorite(item.id) }
                            }
                        )
                        .padding(.horizontal, 8)
                        .transition(rowTransition(index: index))
                    }
                }
            }
        }
    }

    private func rowTransition(index: Int) -> AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .offset(y: -16))
                .combined(with: .scale(scale: 0.97, anchor: .top))
                .animation(Motion.snappy.delay(Double(index) * 0.045)),
            removal: .opacity.animation(.easeOut(duration: 0.16))
        )
    }

    private func items(for section: WardrobeSection) -> [ClothingItem] {
        switch section {
        case .favorites:
            return store.favorites.sorted { $0.category.sortIndex == $1.category.sortIndex ? $0.createdAt < $1.createdAt : $0.category.sortIndex < $1.category.sortIndex }
        case .category(let category):
            return store.items(in: category)
        }
    }

    private func meta(for section: WardrobeSection, items: [ClothingItem]) -> String {
        switch section {
        case .favorites:
            let categories = Set(items.map(\.category)).count
            return categories == 1 ? "from 1 category" : "from \(categories) categories"
        case .category:
            let favorites = items.filter(\.isFavorite).count
            return favorites == 1 ? "1 favorite" : "\(favorites) favorites"
        }
    }
}

extension ClothingCategory {
    var sortIndex: Int { ClothingCategory.allCases.firstIndex(of: self) ?? 0 }
}

/// The folded state of a section: name, piece count, favorites.
struct SectionCard: View {
    let title: String
    let count: Int
    let meta: String
    let style: SectionStyle
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .displayType(TypeScale.cardTitle)
                    Text(count == 1 ? "1 piece" : "\(count) pieces")
                        .font(.closet(.regular, TypeScale.cardCount))
                        .padding(.top, -1)
                        .contentTransition(.numericText())
                    Text(meta)
                        .font(.closet(.regular, TypeScale.cardMeta))
                        .padding(.top, 2)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Icon(glyph: .chevronDown, size: 24)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(Motion.snappy, value: isExpanded)
            }
            .foregroundStyle(Theme.text)
            .padding(.leading, 22)
            .padding(.trailing, 20)
            .padding(.top, 14)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
            .background(GlowingPanel(color: style.card, glow: style.glow, radius: Theme.cardRadius))
            .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        }
        .buttonStyle(PressableStyle(scale: 0.975))
        .accessibilityLabel("\(title), \(count) pieces, \(meta)")
        .accessibilityHint(isExpanded ? "Double tap to fold" : "Double tap to unfold")
    }
}

/// A rounded panel with a soft colored glow, rasterized once so scrolling stays smooth.
struct GlowingPanel: View {
    let color: Color
    let glow: Color
    let radius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(color)
            .shadow(color: glow, radius: 18)
            .padding(28)
            .drawingGroup()
            .padding(-28)
    }
}

/// One piece of clothing inside an unfolded section.
struct ItemRow: View {
    let item: ClothingItem
    let style: SectionStyle
    let onEdit: () -> Void
    let onFavorite: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName.lowercased())
                    .font(.closet(.regular, TypeScale.body))
                    .lineLimit(1)
                    .padding(.bottom, 6)
                HStack(spacing: 7) {
                    Text("color")
                        .font(.closet(.bold, TypeScale.body))
                    Circle()
                        .fill(Color(item.color))
                        .frame(width: 17, height: 17)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6))
                }
                Text(item.primaryAttribute.isEmpty ? "—" : item.primaryAttribute.lowercased())
                    .font(.closet(.regular, TypeScale.body))
                    .lineLimit(1)
                Text(item.secondaryAttribute.isEmpty ? "—" : item.secondaryAttribute.lowercased())
                    .font(.closet(.bold, TypeScale.body))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            StoredImage(fileName: item.imageFileName, maxPixel: 260)
                .frame(width: 70, height: 74)

            VStack(spacing: 4) {
                IconButton(glyph: .pencil, size: 19, label: "Edit \(item.displayName)", action: onEdit)
                    .frame(width: 34, height: 34)
                FavoriteButton(isOn: item.isFavorite, action: onFavorite)
                    .frame(width: 34, height: 34)
                Spacer(minLength: 0)
            }
            .frame(height: 78)
        }
        .foregroundStyle(Theme.text)
        .padding(.leading, 20)
        .padding(.trailing, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.rowRadius, style: .continuous)
                .fill(style.row)
        )
    }
}

/// Star that fills in with a little bounce.
struct FavoriteButton: View {
    let isOn: Bool
    let action: () -> Void

    @State private var scale: CGFloat = 1
    @State private var tilt: Double = 0

    var body: some View {
        Button {
            isOn ? Haptics.selection() : Haptics.light()
            action()
            withAnimation(.spring(response: 0.16, dampingFraction: 0.5)) {
                scale = 1.35
                tilt = isOn ? 0 : -18
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.42)) {
                    scale = 1
                    tilt = 0
                }
            }
        } label: {
            Icon(glyph: .star, size: 19, filled: isOn)
                .animation(Motion.snappy, value: isOn)
                .scaleEffect(scale)
                .rotationEffect(.degrees(tilt))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.85))
        .accessibilityLabel(isOn ? "Remove from favorites" : "Add to favorites")
    }
}

private struct EmptySectionRow: View {
    let section: WardrobeSection

    var body: some View {
        HStack(spacing: 12) {
            Icon(glyph: section == .favorites ? .star : .hanger, size: 20, color: Theme.secondaryText)
            Text(section == .favorites ? "tap the star on a piece to keep it here" : "nothing here yet. scan a piece from home.")
                .font(.closet(.regular, TypeScale.body))
                .foregroundStyle(Theme.secondaryText)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: Theme.rowRadius, style: .continuous)
                .fill(section.style.row.opacity(0.7))
        )
        .padding(.horizontal, 8)
    }
}
