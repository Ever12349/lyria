import AppKit
import LyriaCore
import SwiftUI

struct CoverArt: View {
    var seed: String
    var artworkPath: String? = nil
    /// When non-empty, wins over `artworkPath` (unless `circle`).
    var artworkPaths: [String] = []
    var systemImage: String = "music.note"
    var cornerRadius: CGFloat = 8
    var circle = false
    var elevated = false
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        let shape = circle
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        let paths = displayPaths
        shape
            .fill(LyriaTheme.coverGradient(seed: seed))
            .overlay {
                GeometryReader { geo in
                    coverContent(paths: paths, width: geo.size.width, height: geo.size.height)
                }
            }
            .clipShape(shape)
            .shadow(color: elevated ? LyriaTheme.primaryDeep.opacity(0.35) : .clear, radius: elevated ? 18 : 0, y: elevated ? 8 : 0)
    }

    /// `circle` forces a single tile. Non-empty `artworkPaths` beats `artworkPath`.
    private var displayPaths: [String] {
        if circle {
            if let first = artworkPaths.first(where: { !$0.isEmpty }) { return [first] }
            if let artworkPath, !artworkPath.isEmpty { return [artworkPath] }
            return []
        }
        let multi = artworkPaths.filter { !$0.isEmpty }
        if !multi.isEmpty {
            return Array(multi.prefix(PlaylistArtwork.maxTiles))
        }
        if let artworkPath, !artworkPath.isEmpty { return [artworkPath] }
        return []
    }

    @ViewBuilder
    private func coverContent(paths: [String], width: CGFloat, height: CGFloat) -> some View {
        if paths.isEmpty {
            CoverArtImage(
                artworkPath: nil,
                systemImage: systemImage,
                showsIcon: true,
                width: width,
                height: height,
                displayScale: displayScale
            )
        } else if paths.count == 1 {
            CoverArtImage(
                artworkPath: paths[0],
                systemImage: systemImage,
                showsIcon: true,
                width: width,
                height: height,
                displayScale: displayScale
            )
        } else {
            let edge = Double(min(width, height))
            let tiles = PlaylistArtwork.tiles(count: paths.count, edge: edge)
            ZStack(alignment: .topLeading) {
                ForEach(Array(tiles.enumerated()), id: \.offset) { index, tile in
                    CoverArtImage(
                        artworkPath: paths[index],
                        systemImage: systemImage,
                        showsIcon: false,
                        width: CGFloat(tile.width),
                        height: CGFloat(tile.height),
                        displayScale: displayScale
                    )
                    .frame(width: CGFloat(tile.width), height: CGFloat(tile.height))
                    .clipped()
                    .offset(x: CGFloat(tile.x), y: CGFloat(tile.y))
                }
            }
            .frame(width: width, height: height, alignment: .topLeading)
        }
    }
}

/// Measures itself and asks the thumbnail cache for that bucket. A memory hit is drawn in this body.
private struct CoverArtImage: View {
    var artworkPath: String?
    var systemImage: String
    var showsIcon: Bool
    var width: CGFloat
    var height: CGFloat
    var displayScale: CGFloat
    @State private var artwork: NSImage?
    @State private var artworkID = ""

    var body: some View {
        let request = ArtworkThumbnails.request(
            sourcePath: artworkPath,
            edgePoints: Double(max(width, height)),
            displayScale: Double(displayScale)
        )
        let taskID = request?.key.token ?? ""
        let shown = image(request: request, taskID: taskID)
        ZStack {
            if let shown {
                Image(nsImage: shown)
                    .resizable()
                    .scaledToFill()
            } else if showsIcon {
                Image(systemName: systemImage)
                    .font(.system(size: max(11, width * 0.28), weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
        .frame(width: width, height: height)
        .task(id: taskID) {
            await load(request, taskID: taskID)
        }
    }

    private func image(request: ArtworkThumbRequest?, taskID: String) -> NSImage? {
        guard let request else { return nil }
        if artworkID == taskID { return artwork }
        guard let data = SupportPaths.thumbnails.memoryData(for: request.key) else { return nil }
        return NSImage(data: data)
    }

    private func load(_ request: ArtworkThumbRequest?, taskID: String) async {
        guard let request else {
            artwork = nil
            artworkID = ""
            return
        }
        if let data = SupportPaths.thumbnails.memoryData(for: request.key) {
            artwork = NSImage(data: data)
            artworkID = taskID
            return
        }
        let data = await SupportPaths.thumbnails.thumbnailJPEG(key: request.key)
        guard !Task.isCancelled else { return }
        artwork = data.flatMap { NSImage(data: $0) }
        artworkID = taskID
    }
}
