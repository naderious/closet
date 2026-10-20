import SwiftUI

/// Name, categorize and describe a piece — used both after scanning and when editing.
struct ItemEditorView: View {
    @Environment(Router.self) private var router
    @Environment(WardrobeStore.self) private var store
    @Environment(ScanSession.self) private var scan

    @State private var colorMode: ColorMode = .photo
    @State private var sampler: PixelSampler?
    @State private var isSaving = false
    @State private var confirmingDelete = false
    @FocusState private var focus: Field?

    private enum ColorMode {
        case photo, wheel
    }

    private enum Field: Hashable {
        case name, primary, secondary
    }

    private var draft: ItemDraft {
        scan.draft ?? ItemDraft()
    }

    private var colorBinding: Binding<RGBColor> {
        Binding(get: { scan.draft?.color ?? RGBColor(white: 0.5) }, set: { scan.draft?.color = $0 })
    }

    private func textBinding(_ keyPath: WritableKeyPath<ItemDraft, String>) -> Binding<String> {
        Binding(get: { scan.draft?[keyPath: keyPath] ?? "" }, set: { scan.draft?[keyPath: keyPath] = $0 })
    }

    var body: some View {
        let current = draft
        VStack(spacing: 0) {
            ScreenHeader(title: current.isNew ? "details" : "edit") {
                IconButton(glyph: .chevronLeft, size: 24, label: "Back") { goBack() }
            } trailing: {
                FavoriteButton(isOn: current.isFavorite) {
                    scan.draft?.isFavorite.toggle()
                }
            }
            .entrance(0.04, from: CGSize(width: 0, height: -12))

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    photoSection(current)
                        .entrance(0.1)
                    nameField(current)
                        .entrance(0.16)
                    categoryPicker(current)
                        .entrance(0.2)
                    colorSection(current)
                        .entrance(0.24)
                    attributeField(current.category.primaryField, keyPath: \.primaryAttribute, field: .primary)
                        .entrance(0.28)
                    attributeField(current.category.secondaryField, keyPath: \.secondaryAttribute, field: .secondary)
                        .entrance(0.32)
                    if !current.isNew {
                        deleteButton
                            .entrance(0.36)
                    }
                }
                .padding(.horizontal, Theme.gutter + 4)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollDismissesKeyboard(.interactively)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0), location: 0),
                        .init(color: .black, location: 0.03),
                        .init(color: .black, location: 0.92),
                        .init(color: .black.opacity(0), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            PillButton(title: current.isNew ? "add to closet" : "save", isBusy: isSaving) {
                save()
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .task(id: current.imageKey) {
            guard let image = draft.image else {
                sampler = nil
                return
            }
            sampler = await Task.detached(priority: .userInitiated) { PixelSampler(image: image) }.value
        }
        .confirmationDialog("delete this piece?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("delete", role: .destructive) { delete() }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("it will be removed from your wardrobe and outfits.")
        }
    }

    // MARK: Sections

    private func photoSection(_ current: ItemDraft) -> some View {
        VStack(spacing: 14) {
            if let image = current.image {
                EyedropperImage(image: image, sampler: sampler, isActive: colorMode == .photo, color: colorBinding)
                    .frame(height: 240)
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 240)
            }

            Button {
                Haptics.tap()
                scan.beginRetake()
                router.go(.scan, from: .top)
            } label: {
                HStack(spacing: 7) {
                    Icon(glyph: .camera, size: 15, color: Theme.secondaryText)
                    Text("retake photo")
                        .font(.closet(.regular, 11))
                        .foregroundStyle(Theme.secondaryText)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
        }
        .frame(maxWidth: .infinity)
    }

    private func nameField(_ current: ItemDraft) -> some View {
        FieldBlock(label: "name") {
            UnderlinedField(isFocused: focus == .name) {
                TextField(
                    "",
                    text: textBinding(\.name),
                    prompt: Text(current.suggestedName).foregroundStyle(Theme.tertiaryText)
                )
                .font(.closet(.regular, 15))
                .foregroundStyle(Theme.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focus, equals: .name)
                .onSubmit { focus = nil }
            }
        }
    }

    private func categoryPicker(_ current: ItemDraft) -> some View {
        FieldBlock(label: "category") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ClothingCategory.allCases) { category in
                        Chip(title: category.title, isSelected: current.category == category) {
                            withAnimation(Motion.snappy) { scan.draft?.category = category }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollClipDisabled()
        }
    }

    private func colorSection(_ current: ItemDraft) -> some View {
        FieldBlock(label: "color") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color(current.color))
                        .frame(width: 36, height: 36)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
                        .shadow(color: Color(current.color).opacity(0.55), radius: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ColorNaming.name(for: current.color))
                            .font(.closet(.bold, 13))
                            .contentTransition(.opacity)
                        Text(current.color.hex.lowercased())
                            .font(.closet(.regular, 10))
                            .foregroundStyle(Theme.secondaryText)
                            .contentTransition(.numericText())
                    }
                    Spacer(minLength: 8)
                    HStack(spacing: 6) {
                        Chip(title: "photo", isSelected: colorMode == .photo) {
                            withAnimation(Motion.snappy) { colorMode = .photo }
                        }
                        Chip(title: "wheel", isSelected: colorMode == .wheel) {
                            focus = nil
                            withAnimation(Motion.snappy) { colorMode = .wheel }
                        }
                    }
                }
                .foregroundStyle(Theme.text)

                if colorMode == .photo {
                    HStack(spacing: 8) {
                        Icon(glyph: .eyedropper, size: 15, color: Theme.secondaryText)
                        Text("drag across the photo to pick the exact color")
                            .font(.closet(.regular, 11))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .transition(.opacity)
                } else {
                    ColorWheel(color: colorBinding)
                        .frame(height: 290)
                        .padding(.horizontal, 12)
                        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .top)))
                }
            }
        }
    }

    private func attributeField(_ attribute: AttributeField, keyPath: WritableKeyPath<ItemDraft, String>, field: Field) -> some View {
        let text = textBinding(keyPath)
        return FieldBlock(label: attribute.label) {
            VStack(alignment: .leading, spacing: 10) {
                UnderlinedField(isFocused: focus == field) {
                    TextField(
                        "",
                        text: text,
                        prompt: Text(attribute.suggestions.first ?? "").foregroundStyle(Theme.tertiaryText)
                    )
                    .font(.closet(.regular, 15))
                    .foregroundStyle(Theme.text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($focus, equals: field)
                    .onSubmit { focus = nil }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attribute.suggestions, id: \.self) { suggestion in
                            let selected = text.wrappedValue.lowercased() == suggestion
                            Chip(title: suggestion, isSelected: selected) {
                                withAnimation(Motion.snappy) { text.wrappedValue = selected ? "" : suggestion }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .scrollClipDisabled()
            }
        }
    }

    private var deleteButton: some View {
        Button {
            Haptics.warning()
            confirmingDelete = true
        } label: {
            HStack(spacing: 8) {
                Icon(glyph: .trash, size: 16, color: Theme.secondaryText)
                Text("delete this piece")
                    .font(.closet(.regular, 12))
                    .foregroundStyle(Theme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Actions

    private func goBack() {
        focus = nil
        if draft.isNew {
            router.go(scan.capture != nil ? .review : .scan, from: .left)
        } else {
            scan.reset()
            router.go(.wardrobe, from: .left)
        }
    }

    private func save() {
        guard let current = scan.draft, !isSaving else { return }
        focus = nil
        isSaving = true
        let existing = store.item(current.itemID)

        Task { @MainActor in
            var fileName = current.existingImageFile
            var aspect = existing?.imageAspect ?? 1
            var edges = existing?.edgeProfile
            if let image = current.newImage {
                let processed = await Task.detached(priority: .userInitiated) { () -> (String?, Double, EdgeProfile?) in
                    let name = try? ImageStore.shared.save(image)
                    return (name, image.pixelAspect, image.edgeProfile())
                }.value
                guard let name = processed.0 else {
                    isSaving = false
                    Haptics.warning()
                    return
                }
                fileName = name
                aspect = processed.1
                edges = processed.2
            }

            let trimmedName = current.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let item = ClothingItem(
                id: current.itemID ?? UUID(),
                name: trimmedName.isEmpty ? current.suggestedName : trimmedName,
                category: current.category,
                colorHex: current.color.hex,
                primaryAttribute: current.primaryAttribute.trimmingCharacters(in: .whitespacesAndNewlines),
                secondaryAttribute: current.secondaryAttribute.trimmingCharacters(in: .whitespacesAndNewlines),
                isFavorite: current.isFavorite,
                imageFileName: fileName,
                imageAspect: aspect,
                edgeProfile: edges,
                createdAt: current.createdAt
            )

            Haptics.success()
            if current.isNew {
                store.add(item)
                scan.reset()
                router.go(.scan, from: .bottom)
                router.showToast("added to your wardrobe")
            } else {
                store.update(item)
                scan.reset()
                router.go(.wardrobe, from: .bottom)
                router.showToast("saved")
            }
        }
    }

    private func delete() {
        guard let id = scan.draft?.itemID else { return }
        store.delete(id)
        scan.reset()
        router.go(.wardrobe, from: .bottom)
        router.showToast("deleted")
    }
}

/// A bold label above its control.
struct FieldBlock<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.closet(.bold, 12))
                .foregroundStyle(Theme.text)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A text field with a hairline underline that brightens while editing.
struct UnderlinedField<Content: View>: View {
    let isFocused: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            content
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                Rectangle()
                    .fill(Color.white)
                    .scaleEffect(x: isFocused ? 1 : 0, anchor: .leading)
            }
            .frame(height: 1)
            .animation(Motion.snappy, value: isFocused)
        }
    }
}
