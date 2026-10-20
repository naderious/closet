import SwiftUI

/// Shows a garment image from `ImageStore`, decoding off the main thread.
struct StoredImage: View {
    let fileName: String
    /// Longest side in pixels to decode at.
    var maxPixel: Int = 1000

    @State private var image: UIImage?

    init(fileName: String, maxPixel: Int = 1000) {
        self.fileName = fileName
        self.maxPixel = maxPixel
        _image = State(initialValue: ImageStore.shared.cachedThumbnail(named: fileName, maxPixel: maxPixel))
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
                    .transition(.opacity)
            }
        }
        .task(id: fileName) {
            if let cached = ImageStore.shared.cachedThumbnail(named: fileName, maxPixel: maxPixel) {
                image = cached
                return
            }
            let name = fileName
            let size = maxPixel
            let loaded = await Task.detached(priority: .userInitiated) {
                ImageStore.shared.thumbnail(named: name, maxPixel: size)
            }.value
            withAnimation(.easeOut(duration: 0.2)) { image = loaded }
        }
    }
}
