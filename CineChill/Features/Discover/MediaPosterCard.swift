import SwiftUI

/// Poster tile with title, rating and type badge — shared across screens.
struct MediaPosterCard: View {
    let item: MediaItem
    var width: CGFloat = 128

    private var posterURL: URL? {
        let service = DiscoverService()
        if let path = item.posterPath, let url = service.imageURL(for: path) { return url }
        if let tmdb = item.tmdbID { return service.posterURL(mediaType: item.mediaType, tmdbID: tmdb) }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                PosterTile(url: posterURL, width: width)
                    .overlay(alignment: .bottom) {
                        LinearGradient(colors: [.clear, .black.opacity(0.50)],
                                       startPoint: .center, endPoint: .bottom)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.posterCorner, style: .continuous))
                    }
                if let rating = item.ratingText {
                    GlassPill(rating, systemImage: "star.fill", tint: Theme.accentWarm)
                        .padding(6)
                }
            }
            Text(item.title)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
            HStack(spacing: 4) {
                Text(item.typeLabel)
                if let year = item.year { Text("· \(year)") }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frame(width: width)
        .contentShape(.rect)
    }
}
