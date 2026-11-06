import SwiftUI

struct LibraryView: View {
    let tracks: [Track]
    let nowPlayingId: String?
    @Binding var selectedTrackId: String?
    @Binding var searchText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 14)

            trackListCard
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LyriaTheme.background.opacity(0.001))
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(LyriaTheme.mutedForeground)
            TextField("搜索音乐、艺人、专辑", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(LyriaTheme.foreground)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(LyriaTheme.mutedForeground)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(
            Capsule(style: .continuous)
                .fill(LyriaTheme.searchFill)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(LyriaTheme.border, lineWidth: 1)
        )
    }

    private var trackListCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            tableHeader
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 6)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(tracks) { track in
                        TrackRow(
                            track: track,
                            isNowPlaying: track.id == nowPlayingId,
                            isSelected: track.id == selectedTrackId
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { selectedTrackId = track.id }
                    }

                    if tracks.isEmpty {
                        Text("无匹配曲目")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(LyriaTheme.mutedForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 48)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: LyriaTheme.radiusMD, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LyriaTheme.radiusMD, style: .continuous)
                .strokeBorder(LyriaTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: LyriaTheme.radiusMD, style: .continuous))
    }

    private var tableHeader: some View {
        HStack(spacing: 12) {
            Text("标题")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("艺人")
                .frame(width: 140, alignment: .leading)
            Text("专辑")
                .frame(width: 160, alignment: .leading)
            Text("时长")
                .frame(width: 52, alignment: .trailing)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(LyriaTheme.mutedForeground)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}

private struct TrackRow: View {
    let track: Track
    let isNowPlaying: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isNowPlaying {
                EqualizerGlyph()
                    .frame(width: 16, height: 14)
            } else {
                Color.clear.frame(width: 16, height: 14)
            }

            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 40, height: 40)
                        .overlay {
                            if isNowPlaying {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(LyriaTheme.softAccentGradient)
                            }
                        }
                    Image(systemName: isNowPlaying ? "music.note" : "xmark")
                        .font(.system(size: isNowPlaying ? 14 : 11, weight: .semibold))
                        .foregroundStyle(isNowPlaying ? LyriaTheme.primary : LyriaTheme.mutedForeground.opacity(0.55))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isNowPlaying ? LyriaTheme.primary : LyriaTheme.foreground)
                        .lineLimit(1)
                    Text(track.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(LyriaTheme.mutedForeground)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(track.artist)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(LyriaTheme.mutedForeground)
                .lineLimit(1)
                .frame(width: 140, alignment: .leading)

            Text(track.album)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(LyriaTheme.mutedForeground)
                .lineLimit(1)
                .frame(width: 160, alignment: .leading)

            HStack(spacing: 8) {
                Text(track.durationLabel)
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(LyriaTheme.mutedForeground)
                if isNowPlaying {
                    EqualizerGlyph()
                        .frame(width: 14, height: 12)
                } else {
                    Color.clear.frame(width: 14, height: 12)
                }
            }
            .frame(width: 52 + 22, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: LyriaTheme.radiusSM, style: .continuous)
                .fill(isNowPlaying ? LyriaTheme.sidebarAccent : (isSelected ? Color.white.opacity(0.07) : Color.white.opacity(0.045)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LyriaTheme.radiusSM, style: .continuous)
                .strokeBorder(
                    isNowPlaying ? LyriaTheme.primary.opacity(0.55) : LyriaTheme.border,
                    lineWidth: isNowPlaying ? 1.2 : 1
                )
        )
        .shadow(color: isNowPlaying ? LyriaTheme.primary.opacity(0.22) : .clear, radius: 10, y: 2)
    }
}

private struct EqualizerGlyph: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            Capsule().frame(width: 2.5, height: 6)
            Capsule().frame(width: 2.5, height: 12)
            Capsule().frame(width: 2.5, height: 8)
            Capsule().frame(width: 2.5, height: 10)
        }
        .foregroundStyle(LyriaTheme.primary)
    }
}
