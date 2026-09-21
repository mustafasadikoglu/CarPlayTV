import SwiftUI

public struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let targetSize: CGSize?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?

    public init(
        url: URL?,
        targetSize: CGSize? = nil,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.targetSize = targetSize
        self.content = content
        self.placeholder = placeholder

        // Immediate synchronous memory cache check for zero-flicker rendering
        if let validURL = url, let cached = ImageCacheManager.shared.cachedImageFromMemory(for: validURL) {
            _uiImage = State(initialValue: cached)
        }
    }

    public var body: some View {
        Group {
            if let image = uiImage {
                content(Image(uiImage: image))
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let validURL = url else { return }
            if uiImage == nil {
                let loaded = await ImageCacheManager.shared.loadImage(from: validURL, targetSize: targetSize)
                if !Task.isCancelled {
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            self.uiImage = loaded
                        }
                    }
                }
            }
        }
    }
}
