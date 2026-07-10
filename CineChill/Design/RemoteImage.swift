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
                colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                startPoint: .top, endPoint: .bottom
            )
            if let icon {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.secondary)
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
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
            )
    }
}
