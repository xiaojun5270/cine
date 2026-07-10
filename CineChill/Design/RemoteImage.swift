import SwiftUI

/// Async image with a poster-friendly placeholder and graceful failure.
/// Uses the shared cookie storage so authenticated proxy endpoints work.
struct RemoteImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.25))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: contentMode)
            case .failure:
                placeholder(icon: "photo")
            case .empty:
                placeholder(icon: nil)
            @unknown default:
                placeholder(icon: "photo")
            }
        }
    }

    @ViewBuilder
    private func placeholder(icon: String?) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Theme.accent.opacity(0.14),
                    Theme.accentBlue.opacity(0.10),
                    Color.white.opacity(0.035)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            if let icon {
                Image(systemName: icon)
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.52))
            } else {
                ProgressView().controlSize(.small)
            }
        }
    }
}

/// Standard poster tile (2:3) with rounded corners.
struct PosterTile: View {
    let url: URL?
    var width: CGFloat = 120

    var body: some View {
        RemoteImage(url: url)
            .frame(width: width, height: width * 1.5)
            .clipShape(RoundedRectangle(cornerRadius: Theme.posterCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.posterCorner, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.6)
            )
            .shadow(color: .black.opacity(0.30), radius: 14, y: 8)
    }
}
