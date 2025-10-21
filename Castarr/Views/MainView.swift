//
//  MainView.swift
//  Castarr
//
//  Created by Eric on 7/28/25.
//  Reimagined hero layout and bottom navigation by Codex on 3/8/24.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

// Persistent storage to prevent actor name loss during state refreshes
class ActorNameStore: ObservableObject {
    @Published var storedActorName: String = ""
}

struct MainView: View {
    @ObservedObject var plexService: PlexService
    var onSettingsTap: () -> Void = {}

    @State private var movieMetadata: MovieMetadata?
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Hero / section state
    @State private var isSummaryExpanded = false
    @State private var activeSection: DetailSection = .overview

    // Bottom sheet presentation
    @State private var showingActorDetail = false
    @State private var showingPosterDetail = false

    // Session switcher
    @State private var isSessionMenuPresented = false

    // Actor selection state
    @State private var selectedActorName = ""
    @State private var pendingActorName = ""

    // Background tasks
    @State private var metadataTask: Task<Void, Never>?

    // Persistent helpers
    @StateObject private var actorNameStore = ActorNameStore()
    @StateObject private var imdbService = IMDbService()

    // Sections available for quick navigation
    enum DetailSection: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case ratings = "Ratings"
        case details = "Details"
        case cast = "Cast"

        var id: String { rawValue }
        var title: String { rawValue }
        var icon: String {
            switch self {
            case .overview: return "text.justify.left"
            case .ratings: return "star.circle.fill"
            case .details: return "gearshape.fill"
            case .cast: return "person.3.fill"
            }
        }
        var scrollID: String { "section-\(rawValue.lowercased())" }
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ZStack {
                backgroundLayer

                ScrollView(.vertical, showsIndicators: false) {
                    contentStack
                        .padding(.bottom, 80) // space for bottom menu
                }
                .coordinateSpace(name: "mainScroll")
                .refreshable {
                    await refreshSessions()
                }
            }
            .safeAreaInset(edge: .bottom) {
                GeometryReader { geometry in
                    BottomSectionBar(
                        sections: DetailSection.allCases,
                        activeSection: activeSection,
                        onSelect: { section in
                            withAnimation(.easeInOut(duration: 0.35)) {
                                scrollProxy.scrollTo(section.scrollID, anchor: .top)
                            }
                            activeSection = section
                        },
                        onSettingsTap: onSettingsTap,
                        bottomInset: geometry.safeAreaInsets.bottom
                    )
                    .padding(.bottom, geometry.safeAreaInsets.bottom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .frame(height: 70) // make the inset content just overlay at the bottom
            }
            .overlay(alignment: .bottomTrailing) {
                sessionSwitcher
            }
            .onAppear {
                Task {
                    await plexService.fetchSessions()
                    loadMovieMetadata()
                }
            }
            .onDisappear {
                metadataTask?.cancel()
            }
            .onChange(of: plexService.selectedSessionIndex) { _ in
                isSessionMenuPresented = false
                loadMovieMetadata()
            }
            .onChange(of: plexService.activeVideoSessions.count) { newCount in
                if newCount <= 1 {
                    isSessionMenuPresented = false
                }
                loadMovieMetadata()
            }
            .onChange(of: movieMetadata?.id) { _ in
                activeSection = .overview
            }
        }
        .sheet(isPresented: $showingActorDetail, onDismiss: resetActorSelection) {
            ActorDetailView(
                actorName: resolvedActorName(),
                imdbService: imdbService,
                movieYear: movieMetadata?.year,
                movieIMDbID: movieMetadata?.imdbID,
                movieMetadata: movieMetadata
            )
        }
        .sheet(isPresented: $showingPosterDetail) {
            if let movie = movieMetadata {
                PosterDetailView(
                    posterURL: posterURL(for: movie.thumb),
                    movieTitle: movie.title ?? "Unknown Title"
                )
            }
        }
    }
}

// MARK: - Content
private extension MainView {
    var contentStack: some View {
        VStack(spacing: 28) {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView("Loading movie details…")
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primaryAccent))
                    Text("Pull to refresh if this takes too long.")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.highlight)
                }
                .padding(.top, 120)
            } else if let errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.Colors.primaryAccent)
                    Text("Unable to load details")
                        .font(Theme.Typography.subtitle)
                        .foregroundColor(Theme.Colors.text)
                    Text(errorMessage)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.highlight)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.top, 120)
            } else if plexService.activeVideoSessions.isEmpty {
                emptyStateView
            } else if let movie = movieMetadata {
                heroSection(for: movie)
                    .id("hero")

                overviewSection(for: movie)
                    .id(DetailSection.overview.scrollID)

                if let ratings = movie.ratings, !ratings.isEmpty {
                    ratingsSection(ratings: ratings)
                        .id(DetailSection.ratings.scrollID)
                }

                let techRows = technicalRows(for: movie)
                if !techRows.isEmpty {
                    technicalDetailsSection(rows: techRows)
                        .id(DetailSection.details.scrollID)
                }

                if let cast = movie.roles, !cast.isEmpty {
                    castSection(cast: cast)
                        .id(DetailSection.cast.scrollID)
                } else {
                    emptyCastPlaceholder
                        .id(DetailSection.cast.scrollID)
                }
            } else {
                placeholderState
            }
        }
    }

    @ViewBuilder
    var sessionSwitcher: some View {
        if plexService.activeVideoSessions.isEmpty {
            EmptyView()
        } else {
            SessionSwitcherControl(
                sessions: plexService.activeVideoSessions,
                selectedIndex: plexService.selectedSessionIndex,
                otherCount: plexService.otherActiveVideoSessionsCount,
                isPresented: $isSessionMenuPresented,
                isOwned: { plexService.isOwned(videoSession: $0) },
                onSelect: { index in
                    plexService.selectedSessionIndex = index
                }
            )
            .padding(.trailing, 20)
            .padding(.bottom, 90 + safeAreaBottomInset)
        }
    }

    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tv.slash.fill")
                .font(.system(size: 56))
                .foregroundColor(Theme.Colors.highlight)
            Text("No Active Sessions")
                .font(Theme.Typography.subtitle)
                .foregroundColor(Theme.Colors.text)
            Text("Start playing something on your Plex server to see details here.")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.highlight)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 120)
    }

    var placeholderState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primaryAccent))
            Text("Fetching metadata…")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.highlight)
        }
        .padding(.top, 120)
    }

    func heroSection(for movie: MovieMetadata) -> some View {
        HeroHeaderView(
            movie: movie,
            posterURL: posterURL(for: movie.thumb),
            onPosterTap: {
                showingPosterDetail = true
            }
        )
    }

    func overviewSection(for movie: MovieMetadata) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "Overview", iconName: DetailSection.overview.icon)

            if let tagline = movie.tagline, !tagline.isEmpty {
                Text(tagline)
                    .font(Theme.Typography.subtitle)
                    .foregroundColor(Theme.Colors.text)
            }

            if let summary = movie.summary, !summary.isEmpty {
                ExpandableText(text: summary, isExpanded: $isSummaryExpanded)
            }

            if let genres = movie.genres, !genres.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Genres")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Theme.Colors.text)
                    SimpleFlowLayout(genres, spacing: 8) { genre in
                        Text(genre.tag)
                            .themeTag()
                    }
                }
            }

            if let studio = movie.studio, !studio.isEmpty {
                LabeledRow(label: "Studio", value: studio)
            }

            if let availableDate = movie.originallyAvailableAt, !availableDate.isEmpty {
                LabeledRow(label: "Released", value: availableDate)
            }
        }
        .themeCard()
        .padding(.horizontal, 20)
    }

    func ratingsSection(ratings: [MovieRating]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "Ratings", iconName: DetailSection.ratings.icon)

            VStack(alignment: .leading, spacing: 12) {
                ratingsRow(title: "Rotten Tomatoes", imageKeyword: "rottentomatoes", ratings: ratings)
                ratingsRow(title: "IMDb", imageKeyword: "imdb", ratings: ratings)
                ratingsRow(title: "TMDb", imageKeyword: "themoviedb", ratings: ratings)
            }
        }
        .themeCard()
        .padding(.horizontal, 20)
    }

    func technicalDetailsSection(rows: [TechnicalRow]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeaderView(title: "Technical Details", iconName: DetailSection.details.icon)

            VStack(spacing: 12) {
                ForEach(rows) { row in
                    HStack {
                        Text(row.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Theme.Colors.highlight)
                        Spacer()
                        Text(row.value)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.text)
                    }
                    if row.id != rows.last?.id {
                        Divider()
                            .background(Theme.Colors.highlight.opacity(0.2))
                    }
                }
            }
        }
        .themeCard()
        .padding(.horizontal, 20)
    }

    func castSection(cast: [MovieRole]) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            SectionHeaderView(title: "Cast", iconName: DetailSection.cast.icon)

            LazyVGrid(columns: gridColumns, spacing: 24) {
                ForEach(cast) { role in
                    Button {
                        storeActorSelection(role: role)
                        showingActorDetail = true
                    } label: {
                        CastAvatarCard(
                            role: role,
                            imageSize: avatarSize,
                            cardWidth: avatarCardWidth,
                            thumbnailURL: thumbnailURL(for: role.thumb)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    var emptyCastPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(title: "Cast", iconName: DetailSection.cast.icon)
            Text("No cast information available yet.")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.highlight)
        }
        .themeCard()
        .padding(.horizontal, 20)
    }
}

// MARK: - Bottom Navigation
private struct BottomSectionBar: View {
    let sections: [MainView.DetailSection]
    let activeSection: MainView.DetailSection
    let onSelect: (MainView.DetailSection) -> Void
    let onSettingsTap: () -> Void
    let bottomInset: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            ForEach(sections) { section in
                Button {
                    onSelect(section)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: section.icon)
                            .font(.system(size: 18, weight: .semibold))
                        Text(section.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(section == activeSection ? Theme.Colors.primaryAccent : Theme.Colors.surface.opacity(0.85))
                    )
                    .foregroundColor(section == activeSection ? Theme.Colors.background : Theme.Colors.highlight)
                }
                .buttonStyle(.plain)
            }

            Button(action: onSettingsTap) {
                VStack(spacing: 6) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Settings")
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Theme.Colors.surface.opacity(0.85))
                )
                .foregroundColor(Theme.Colors.highlight)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, bottomInset + 12)
        .background(
            Theme.Colors.background
                .opacity(0.96)
                .overlay(
                    Divider()
                        .background(Theme.Colors.surface.opacity(0.6)),
                    alignment: .top
                )
        )
    }

}

private struct SessionSwitcherControl: View {
    let sessions: [VideoSession]
    let selectedIndex: Int
    let otherCount: Int
    @Binding var isPresented: Bool
    let isOwned: (VideoSession) -> Bool
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if isPresented {
                sessionMenu
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            switcherButton
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
    }

    private var switcherButton: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                isPresented.toggle()
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(Theme.Colors.surface.opacity(0.95))
                    .frame(width: 56, height: 56)
                    .shadow(color: Theme.Colors.background.opacity(0.45), radius: 12, x: 0, y: 10)
                    .overlay(
                        Image(systemName: "rectangle.stack.person.crop")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(Theme.Colors.primaryAccent)
                    )

                if otherCount > 0 {
                    Text("\(otherCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.Colors.background)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(Theme.Colors.primaryAccent)
                        )
                        .offset(x: 16, y: -10)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Active streams")
        .accessibilityHint("Shows a menu of other active streams")
        .accessibilityValue(otherCount > 0 ? "\(otherCount) other streams" : "No other streams")
    }

    private var sessionMenu: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        isPresented = false
                    }
                    onSelect(index)
                } label: {
                    sessionRow(for: session, index: index)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: 260)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Colors.surface.opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.Colors.highlight.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: Theme.Colors.background.opacity(0.35), radius: 14, x: 0, y: 10)
    }

    private func sessionRow(for session: VideoSession, index: Int) -> some View {
        let isSelected = index == selectedIndex
        let ownedByUser = isOwned(session)

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.title ?? "Unknown Title")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.text)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let userTitle = session.user?.title {
                        Text(ownedByUser ? "You" : userTitle)
                            .font(Theme.Typography.caption)
                            .fontWeight(ownedByUser ? .semibold : .regular)
                            .foregroundColor(ownedByUser ? Theme.Colors.secondaryAccent : Theme.Colors.highlight)
                    }

                    if let state = session.player?.state?.capitalized {
                        Text(state)
                            .font(Theme.Typography.caption)
                            .foregroundColor(state.lowercased() == "playing" ? Theme.Colors.secondaryAccent : Theme.Colors.highlight)
                    }
                }

                if let device = session.player?.title {
                    Text(device)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.highlight)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.Colors.primaryAccent)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Theme.Colors.surface.opacity(0.97) : Theme.Colors.surface.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Theme.Colors.primaryAccent.opacity(0.7) : Color.clear, lineWidth: 1.2)
        )
    }
}


#if os(iOS)
private var safeAreaBottomInset: CGFloat {
        guard
            let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
            let window = scene.windows.first(where: { $0.isKeyWindow })
        else {
            return 0
        }
        return window.safeAreaInsets.bottom
    }
#else
    private var safeAreaBottomInset: CGFloat { 0 }
#endif


// MARK: - Cast Grid Helpers
private extension MainView {
    var gridColumns: [GridItem] {
        #if os(iOS)
        let minimum = avatarCardWidth
        return [GridItem(.adaptive(minimum: minimum), spacing: 18)]
        #else
        return [GridItem(.adaptive(minimum: 120), spacing: 18)]
        #endif
    }

    var avatarSize: CGFloat {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? 150 : 116
        #else
        return 120
        #endif
    }

    var avatarCardWidth: CGFloat {
        avatarSize + 70
    }
}

// MARK: - Background
private extension MainView {
    var backgroundLayer: some View {
        Group {
            if let movie = movieMetadata, let colors = movie.ultraBlurColors {
                createGradientBackground(colors: colors)
                    .ignoresSafeArea()
            } else {
                Theme.Colors.background
                    .ignoresSafeArea()
            }
        }
    }
}

// MARK: - State helpers
private extension MainView {

    func storeActorSelection(role: MovieRole) {
        actorNameStore.storedActorName = role.tag
        pendingActorName = role.tag
        selectedActorName = role.tag
        print("🎬 Selected actor: \(role.tag)")
    }

    func resetActorSelection() {
        selectedActorName = ""
        pendingActorName = ""
        actorNameStore.storedActorName = ""
    }

    func resolvedActorName() -> String {
        if !selectedActorName.isEmpty { return selectedActorName }
        if !pendingActorName.isEmpty { return pendingActorName }
        return actorNameStore.storedActorName
    }

    @ViewBuilder
    func ratingsRow(title: String, imageKeyword: String, ratings: [MovieRating]) -> some View {
        let filtered = ratings.filter { ($0.image ?? "").contains(imageKeyword) }
        if !filtered.isEmpty {
            HStack(spacing: 12) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Theme.Colors.highlight)
                Spacer()
                ForEach(filtered, id: \.computedId) { rating in
                    RatingBadgeView(rating: rating, keyword: imageKeyword, formattedValue: rating.value.map(formatRating))
                }
            }
        }
    }

    func technicalRows(for movie: MovieMetadata) -> [TechnicalRow] {
        var rows: [TechnicalRow] = []

        if let runtime = movie.duration, runtime > 0 {
            rows.append(.init(label: "Runtime", value: formatTime(runtime)))
        }

        if let resolution = movie.technical?.videoResolution, !resolution.isEmpty {
            rows.append(.init(label: "Resolution", value: resolution.uppercased()))
        }

        if let codec = movie.technical?.videoCodec, !codec.isEmpty {
            rows.append(.init(label: "Video Codec", value: codec.uppercased()))
        }

        if let frameRate = movie.technical?.videoFrameRate, !frameRate.isEmpty {
            rows.append(.init(label: "Frame Rate", value: "\(frameRate) fps"))
        }

        if let aspect = movie.technical?.aspectRatio, !aspect.isEmpty {
            rows.append(.init(label: "Aspect Ratio", value: aspect))
        }

        if let audioCodec = movie.technical?.audioCodec, !audioCodec.isEmpty {
            rows.append(.init(label: "Audio Codec", value: audioCodec.uppercased()))
        }

        if let channels = movie.technical?.audioChannels {
            rows.append(.init(label: "Audio Channels", value: formattedChannels(channels)))
        }

        if let bitrate = movie.technical?.bitrate, bitrate > 0 {
            rows.append(.init(label: "Bitrate", value: formatBitrate(bitrate)))
        }

        if let container = movie.technical?.container, !container.isEmpty {
            rows.append(.init(label: "Container", value: container.uppercased()))
        }

        if let fileSize = movie.technical?.fileSize, fileSize > 0 {
            rows.append(.init(label: "File Size", value: formatFileSize(fileSize)))
        }

        return rows
    }

    func formattedChannels(_ channels: Int) -> String {
        switch channels {
        case 6: return "5.1"
        case 8: return "7.1"
        default: return "\(channels) ch"
        }
    }

    func formatBitrate(_ bitrate: Int) -> String {
        if bitrate >= 1_000_000 {
            let mbps = Double(bitrate) / 1_000_000
            return String(format: "%.1f Mbps", mbps)
        } else if bitrate >= 1_000 {
            let kbps = Double(bitrate) / 1_000
            return String(format: "%.0f Kbps", kbps)
        } else {
            return "\(bitrate) bps"
        }
    }

    func formatFileSize(_ bytes: Int) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        return String(format: value >= 10 || unitIndex == 0 ? "%.0f %@" : "%.1f %@", value, units[unitIndex])
    }

    func posterURL(for thumbPath: String?) -> URL? {
        guard let thumbPath = thumbPath else { return nil }

        if thumbPath.hasPrefix("http://") || thumbPath.hasPrefix("https://") {
            return URL(string: thumbPath)
        }

        let urlString = "http://\(plexService.settings.serverIP):32400\(thumbPath)?X-Plex-Token=\(plexService.settings.plexToken)"
        return URL(string: urlString)
    }

    func thumbnailURL(for thumbPath: String?) -> URL? {
        guard let thumbPath = thumbPath else { return nil }

        if thumbPath.hasPrefix("http://") || thumbPath.hasPrefix("https://") {
            return URL(string: thumbPath)
        }

        let urlString = "http://\(plexService.settings.serverIP):32400\(thumbPath)?X-Plex-Token=\(plexService.settings.plexToken)"
        return URL(string: urlString)
    }

    func formatTime(_ milliseconds: Int) -> String {
        let totalSeconds = milliseconds / 1000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    func refreshSessions() async {
        print("🔄 MainView: Pull-to-refresh triggered")

        await plexService.fetchSessions()

        let updatedSessions = plexService.activeVideoSessions

        print("🔄 Sessions after refresh: \(updatedSessions.count)")
        print("🔄 Current selected index: \(plexService.selectedSessionIndex)")

        if updatedSessions.isEmpty {
            plexService.selectedSessionIndex = 0
            movieMetadata = nil
            isLoading = false
            isSessionMenuPresented = false
            return
        }

        if updatedSessions.count <= 1 {
            isSessionMenuPresented = false
        }

        loadMovieMetadata()
    }

    func loadMovieMetadata() {
        guard let currentSession = plexService.selectedVideoSession else {
            print("⚠️ No selected session available for metadata fetch")
            movieMetadata = nil
            isLoading = false
            return
        }

        print("🎬 Loading metadata for session \(plexService.selectedSessionIndex): \(currentSession.title ?? "Unknown")")

        metadataTask?.cancel()

        isLoading = true
        errorMessage = nil

        metadataTask = Task {
            do {
                let response = try await plexService.getMovieMetadata(ratingKey: currentSession.id)

                if Task.isCancelled { return }

                await MainActor.run {
                    movieMetadata = response.mediaContainer.video?.first
                    isLoading = false
                }

            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    func createGradientBackground(colors: UltraBlurColors) -> some View {
        let topLeft = Color(hex: colors.topLeft ?? "000000")
        let topRight = Color(hex: colors.topRight ?? "000000")
        let bottomLeft = Color(hex: colors.bottomLeft ?? "000000")
        let bottomRight = Color(hex: colors.bottomRight ?? "000000")

        return LinearGradient(
            colors: [
                topLeft.opacity(0.55),
                topRight.opacity(0.35),
                bottomLeft.opacity(0.4),
                bottomRight.opacity(0.55)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func formatRating(_ value: Double) -> String {
        if value.isNaN || value.isInfinite {
            return "N/A"
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - Hero Header
private struct HeroHeaderView: View {
    let movie: MovieMetadata
    let posterURL: URL?
    let onPosterTap: () -> Void

    private let baseHeight: CGFloat = 360
    private let minHeight: CGFloat = 200

    var body: some View {
        GeometryReader { geo in
            let offset = geo.frame(in: .named("mainScroll")).minY
            let stretchOffset = max(offset, 0)
            let collapseOffset = min(offset, 0) / 2 // slow collapse speed
            let height = baseHeight + stretchOffset

            ZStack(alignment: .bottomLeading) {
                posterBackground(width: geo.size.width, height: height, offset: offset)

                LinearGradient(
                    colors: [
                        Theme.Colors.background.opacity(0.0),
                        Theme.Colors.background.opacity(0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(movie.title ?? "Unknown Title")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(Theme.Colors.text)
                                .lineLimit(2)
                            metaRow
                        }
                        Spacer()
                        if posterURL != nil {
                            Button(action: onPosterTap) {
                                Image(systemName: "rectangle.portrait.and.arrow.up.right")
                                    .font(.headline)
                                    .padding(10)
                                    .background(Theme.Colors.secondaryAccent.opacity(0.9))
                                    .foregroundColor(Theme.Colors.background)
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .frame(height: height)
            .offset(y: collapseOffset)
        }
        .frame(height: baseHeight)
    }

    @ViewBuilder
    private func posterBackground(width: CGFloat, height: CGFloat, offset: CGFloat) -> some View {
        if let posterURL {
            AsyncImage(url: posterURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure(_):
                    fallback
                case .empty:
                    fallback
                @unknown default:
                    fallback
                }
            }
            .frame(width: max(width, UIScreen.main.bounds.width), height: height)
            .clipped()
        } else {
            fallback
                .frame(width: max(width, UIScreen.main.bounds.width), height: height)
        }
    }

    private var metaRow: some View {
        HStack(spacing: 12) {
            if let year = movie.year {
                MetaChip(text: String(year))
            }
            if let duration = movie.duration {
                MetaChip(text: formatRuntime(duration))
            }
            if let contentRating = movie.contentRating {
                MetaChip(text: contentRating)
            }
        }
    }

    private var fallback: some View {
        LinearGradient(
            colors: [
                Theme.Colors.background,
                Theme.Colors.surface.opacity(0.6)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func formatRuntime(_ millis: Int) -> String {
        let minutes = millis / 60000
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return "\(hours)h \(remainder)m"
        } else {
            return "\(minutes)m"
        }
    }

    private struct MetaChip: View {
        let text: String
        var body: some View {
            Text(text)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.Colors.background.opacity(0.65))
                .foregroundColor(Theme.Colors.text)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Reusable Views
private struct SectionHeaderView: View {
    let title: String
    let iconName: String

    var body: some View {
        HStack {
            Label(title, systemImage: iconName)
                .font(.system(.title3, design: .default).weight(.semibold))
                .foregroundColor(Theme.Colors.text)
            Spacer()
        }
    }
}

private struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Theme.Colors.highlight)
            Spacer()
            Text(value)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.text)
        }
    }
}

private struct RatingBadgeView: View {
    let rating: MovieRating
    let keyword: String
    let formattedValue: String?

    @ViewBuilder
    private var labelView: some View {
        if keyword.contains("rottentomatoes") {
            if rating.type == "critic" {
                Text("🍅")
            } else {
                Image(systemName: "person.3.fill")
            }
        } else if keyword.contains("imdb") {
            Text("IMDb")
                .font(.caption2.weight(.bold))
        } else if keyword.contains("themoviedb") {
            Text("TMDb")
                .font(.caption2.weight(.bold))
        } else {
            Image(systemName: "star.fill")
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            labelView
            if let formattedValue {
                Text(formattedValue)
                    .font(.caption.weight(.semibold))
            }
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.Colors.surface.opacity(0.85))
        .foregroundColor(Theme.Colors.text)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ExpandableText: View {
    let text: String
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.text)
                .lineLimit(isExpanded ? nil : 4)

            Button(isExpanded ? "Show Less" : "Read More") {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundColor(Theme.Colors.secondaryAccent)
        }
    }
}

private struct CastAvatarCard: View {
    let role: MovieRole
    let imageSize: CGFloat
    let cardWidth: CGFloat
    let thumbnailURL: URL?

    var body: some View {
        VStack(spacing: 10) {
            AsyncImage(url: thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure(_):
                    placeholder
                case .empty:
                    placeholder.overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primaryAccent))
                    )
                @unknown default:
                    placeholder
                }
            }
            .frame(width: imageSize, height: imageSize)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Theme.Colors.primaryAccent.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Theme.Colors.primaryAccent.opacity(0.18), radius: 8, y: 4)

            VStack(spacing: 4) {
                Text(role.tag)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Theme.Colors.text)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
                if let character = role.role, !character.isEmpty {
                    Text(character)
                        .font(.caption)
                        .foregroundColor(Theme.Colors.highlight)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .frame(width: cardWidth)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Colors.surface.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.Colors.highlight.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private var placeholder: some View {
        Circle()
            .fill(Theme.Colors.surface.opacity(0.7))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 34))
                    .foregroundColor(Theme.Colors.highlight)
            )
    }
}

private struct TechnicalRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

// Simplified flow layout for pill-shaped items (iOS 15 compatible)
struct SimpleFlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let items: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content

    init(_ items: Data, spacing: CGFloat = 8, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.items = items
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(createRows()), id: \.0) { _, rowItems in
                HStack(spacing: spacing) {
                    ForEach(rowItems) { item in
                        content(item)
                    }
                    Spacer()
                }
            }
        }
    }

    private func createRows() -> [(Int, [Data.Element])] {
        var rows: [(Int, [Data.Element])] = []
        var currentRow: [Data.Element] = []
        var rowIndex = 0

        let itemsPerRow = 3

        for item in items {
            currentRow.append(item)

            if currentRow.count == itemsPerRow {
                rows.append((rowIndex, currentRow))
                currentRow = []
                rowIndex += 1
            }
        }

        if !currentRow.isEmpty {
            rows.append((rowIndex, currentRow))
        }

        return rows
    }
}

// Poster detail view for expanded poster display
struct PosterDetailView: View {
    let posterURL: URL?
    let movieTitle: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack {
                        Spacer()

                        AsyncImage(url: posterURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            Rectangle()
                                .foregroundColor(Theme.Colors.highlight.opacity(0.8))
                                .aspectRatio(2/3, contentMode: .fit)
                                .overlay(
                                    ProgressView()
                                        .scaleEffect(1.5)
                                )
                        }
                        .frame(maxWidth: min(geometry.size.width * 0.9, geometry.size.height * 0.6))
                        .cornerRadius(12)
                        .shadow(radius: 10)

                        Spacer()
                    }
                    .frame(minHeight: geometry.size.height)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle(movieTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
