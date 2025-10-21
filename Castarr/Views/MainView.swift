//
//  MainView.swift
//  RoleCall
//
//  Created by Eric on 7/28/25.
//

import SwiftUI

// Persistent storage to prevent actor name loss during state refreshes
class ActorNameStore: ObservableObject {
    @Published var storedActorName: String = ""
}

struct MainView: View {
    @ObservedObject var plexService: PlexService
    @State private var movieMetadata: MovieMetadata?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isMovieInfoExpanded = false
    @State private var showingActorDetail = false
    @State private var showingPosterDetail = false
    @State private var selectedActorName = ""
    @State private var pendingActorName = "" // Backup for actor name to prevent state loss
    @State private var metadataTask: Task<Void, Never>? // Track current metadata loading task

    // Persistent storage for actor name that survives state refreshes
    @StateObject private var actorNameStore = ActorNameStore()
    @StateObject private var imdbService = IMDbService()

    var body: some View {
        ZStack {
            // Background gradient using ultra blur colors
            if let movie = movieMetadata, let colors = movie.ultraBlurColors {
                createGradientBackground(colors: colors)
                    .ignoresSafeArea()
            } else {
                // Fallback background
                LinearGradient(
                    colors: [Theme.Colors.background, Theme.Colors.surface.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }

            ScrollView {
                VStack(spacing: 8) {
                    if isLoading {
                        ProgressView("Loading movie details...")
                            .padding()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primaryAccent))
                    } else if let errorMessage = errorMessage {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(Theme.Colors.error)
                            .padding()
                    } else {
                        content
                    }
                }
                .padding(.top, 2)
                .foregroundColor(Theme.Colors.text)
            }
            .refreshable {
                await refreshSessions()
            }
        }
        .onAppear {
            // Fetch sessions data when the app loads, then load movie metadata
            Task {
                await plexService.fetchSessions()
                loadMovieMetadata()
            }
        }

        .onDisappear {
            // Cancel any pending metadata task when view disappears
            metadataTask?.cancel()
        }
        .onChange(of: plexService.selectedSessionIndex) { newValue in
            // Reload movie metadata when session selection changes
            print("🔄 MainView: Session selection changed to \(newValue)")
            loadMovieMetadata()
        }
    }
    
    private func refreshSessions() async {
        print("🔄 MainView: Pull-to-refresh triggered")
        
        // Store the current session information before refresh
        let videoSessionsBeforeRefresh = plexService.activeVideoSessions
        let currentSessionIndex = plexService.selectedSessionIndex
        
        // Always fetch fresh session data
        await plexService.fetchSessions()
        
        // Get updated session information
        let videoSessionsAfterRefresh = plexService.activeVideoSessions
        
        print("🔄 MainView: Sessions before refresh: \(videoSessionsBeforeRefresh.count)")
        print("🔄 MainView: Sessions after refresh: \(videoSessionsAfterRefresh.count)")
        print("🔄 MainView: Current selected index: \(currentSessionIndex)")
        
        // Handle session selection based on the new requirements
        if videoSessionsAfterRefresh.isEmpty {
            // No sessions: Reset to default and show "nothing playing"
            print("🔄 MainView: No active sessions - showing 'nothing playing' page")
            plexService.selectedSessionIndex = 0
            // Clear current movie metadata since there's nothing playing
            movieMetadata = nil
        } else if videoSessionsAfterRefresh.count == 1 {
            // Single session: Keep showing that session (set index to 0)
            print("🔄 MainView: Single session - keeping current display")
            plexService.selectedSessionIndex = 0
            // Reload metadata for the single session
            loadMovieMetadata()
        } else {
            // Multiple sessions: Preserve current selection if it's still valid
            if currentSessionIndex < videoSessionsAfterRefresh.count {
                print("🔄 MainView: Multiple sessions - preserving current selection (index \(currentSessionIndex))")
                // Keep the current selection and reload its metadata
                loadMovieMetadata()
            } else {
                print("🔄 MainView: Current selection out of bounds - resetting to first session")
                // Current selection is out of bounds, reset to first session
                plexService.selectedSessionIndex = 0
                loadMovieMetadata()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let videoSessions = plexService.activeVideoSessions
        if !videoSessions.isEmpty {
            VStack(spacing: 8) {
                // Movie details
                if let movie = movieMetadata {
                    movieDetailsView(movie: movie)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)
        } else {
            VStack(spacing: 16) {
                Image(systemName: "tv.slash")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.Colors.highlight)

                Text("No Active Sessions")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("Start playing something on your Plex server to see details here.")
                    .font(.body)
                    .foregroundColor(Theme.Colors.highlight)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    private func movieDetailsView(movie: MovieMetadata) -> some View {
        VStack(alignment: .leading, spacing: 40) {
            // Movie title - redesigned to be more compact and elegant
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Theme.Colors.surface.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Theme.Colors.highlight.opacity(0.15), lineWidth: 1)
                    )
                    .onTapGesture {
                        print("🎬 MainView: Movie title tapped")
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isMovieInfoExpanded.toggle()
                        }
                        print("🎬 MainView: isMovieInfoExpanded is now: \(isMovieInfoExpanded)")
                    }
                
                HStack {
                    Text(movie.title ?? "Unknown Title")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.text)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.highlight)
                        .opacity(0.6)
                        .rotationEffect(.degrees(isMovieInfoExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.3), value: isMovieInfoExpanded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .allowsHitTesting(false)
            }
            .padding(.bottom, 20)

            // Collapsible movie info section
            if isMovieInfoExpanded {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Movie poster and basic info section
                        HStack(alignment: .top, spacing: 12) {
                            // Movie poster
                            Button(action: {
                                showingPosterDetail = true
                            }) {
                                AsyncImage(url: posterURL(for: movie.thumb)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(2/3, contentMode: .fit)
                                } placeholder: {
                                    Rectangle()
                                        .foregroundColor(Theme.Colors.surface.opacity(0.6))
                                        .aspectRatio(2/3, contentMode: .fit)
                                }
                                .frame(width: 80)
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())

                            // Basic info
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    if let year = movie.year {
                                        Text(String(year))
                                            .font(.subheadline)
                                            .foregroundColor(Theme.Colors.highlight)
                                    }

                                    if let contentRating = movie.contentRating {
                                        Text(contentRating)
                                            .themeTag(accent: Theme.Colors.secondaryAccent)
                                    }
                                }

                                if let duration = movie.duration {
                                    Text(formatTime(duration))
                                        .font(.caption)
                                        .foregroundColor(Theme.Colors.highlight)
                                }

                                // Ratings section
                                if let ratings = movie.ratings, !ratings.isEmpty {
                                    ratingsView(ratings: ratings)
                                        .onAppear {
                                            print("🎭 MainView: Displaying \(ratings.count) ratings")
                                            for (index, rating) in ratings.enumerated() {
                                                print("   Rating \(index): type=\(rating.type ?? "nil"), value=\(rating.value ?? -1), image=\(rating.image ?? "nil")")
                                            }
                                        }
                                } else {
                                    Text("No ratings available")
                                        .font(.caption)
                                        .foregroundColor(Theme.Colors.highlight)
                                        .onAppear {
                                            print("🎭 MainView: No ratings to display - ratings: \(movie.ratings?.count ?? 0)")
                                        }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Summary
                        if let summary = movie.summary {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Summary")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(summary)
                                    .font(.body)
                                    .lineLimit(nil)
                            }
                        }

                        // Genres
                        if let genres = movie.genres, !genres.isEmpty {
                            genrePillsView(genres: genres)
                        }

                        // Countries
                        if let countries = movie.countries, !countries.isEmpty {
                            countriesView(countries: countries)
                        }

                        // Directors
                        if let directors = movie.directors, !directors.isEmpty {
                            directorsView(directors: directors)
                        }

                        // Writers
                        if let writers = movie.writers, !writers.isEmpty {
                            writersView(writers: writers)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.Colors.surface.opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Theme.Colors.highlight.opacity(0.12), lineWidth: 1)
                        )
                )
            }

            // Cast section - always visible with refined spacing
            if let roles = movie.roles, !roles.isEmpty {
                castView(cast: roles)
            }
        }
    }

    private func ratingsView(ratings: [MovieRating]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ratings")
                .font(.subheadline)
                .fontWeight(.medium)

            VStack(alignment: .leading, spacing: 6) {
                // First row: Rotten Tomatoes (critic and audience)
                HStack(spacing: 8) {
                    ForEach(ratings.filter { $0.image?.contains("rottentomatoes") == true }, id: \.computedId) { rating in
                        HStack(spacing: 4) {
                            if rating.type == "critic" {
                                // Tomato with color based on Fresh (≥6.0) vs Rotten (<6.0)
                                let isFresh = (rating.value ?? 0) >= 6.0
                                Text("🍅")
                                    .font(.caption)
                                    .foregroundColor(isFresh ? Theme.Colors.primaryAccent : Theme.Colors.highlight)
                            } else {
                                // Audience rating - keep person icon
                                Image(systemName: "person.fill")
                                    .foregroundColor(Theme.Colors.secondaryAccent)
                                    .font(.caption)
                            }

                            if let value = rating.value {
                                Text(formatRating(value))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.surface.opacity(0.8))
                        .cornerRadius(6)
                    }
                    Spacer()
                }

                // Second row: IMDb ratings
                HStack(spacing: 8) {
                    ForEach(ratings.filter { $0.image?.contains("imdb") == true }, id: \.computedId) { rating in
                        HStack(spacing: 4) {
                            if let image = rating.image {
                                if image.contains("imdb") {
                                    Text("IMDb")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .foregroundColor(Theme.Colors.primaryAccent)
                                }
                            }

                            if let value = rating.value {
                                Text(formatRating(value))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.surface.opacity(0.8))
                        .cornerRadius(6)
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            print("DEBUG - Movie ratings count: \(ratings.count)")
            for (index, rating) in ratings.enumerated() {
                print("DEBUG - Rating \(index): image=\(rating.image ?? "nil"), value=\(rating.value?.description ?? "nil"), type=\(rating.type ?? "nil"), id=\(rating.id ?? "nil")")
            }
        }
    }

    private func genrePillsView(genres: [MovieGenre]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Genres")
                .font(.headline)

            SimpleFlowLayout(genres, spacing: 8) { genre in
                Text(genre.tag)
                    .themeTag(accent: Theme.Colors.secondaryAccent)
            }
        }
    }

    private func countriesView(countries: [MovieCountry]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Countries")
                .font(.headline)

            SimpleFlowLayout(countries, spacing: 8) { country in
                Text(country.tag)
                    .themeTag(accent: Theme.Colors.primaryAccent)
            }
        }
    }

    private func directorsView(directors: [MovieDirector]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Directors")
                .font(.headline)

            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(directors) { director in
                    HStack {
                        AsyncImage(url: thumbnailURL(for: director.thumb)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure(_):
                                Image(systemName: "person.fill")
                                    .foregroundColor(Theme.Colors.highlight)
                                    .font(.title2)
                            case .empty:
                                Image(systemName: "person.fill")
                                    .foregroundColor(Theme.Colors.highlight)
                                    .font(.title2)
                            @unknown default:
                                Image(systemName: "person.fill")
                                    .foregroundColor(Theme.Colors.highlight)
                                    .font(.title2)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .background(Circle().fill(Theme.Colors.surface.opacity(0.6)))

                        Text(director.tag)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.Colors.surface.opacity(0.8))
                    .cornerRadius(8)
                }
            }
        }
    }

    private func writersView(writers: [MovieWriter]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Writers")
                .font(.headline)

            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(writers) { writer in
                    HStack {
                        AsyncImage(url: thumbnailURL(for: writer.thumb)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure(_):
                                Image(systemName: "person.fill")
                                    .foregroundColor(Theme.Colors.highlight)
                                    .font(.title2)
                            case .empty:
                                Image(systemName: "person.fill")
                                    .foregroundColor(Theme.Colors.highlight)
                                    .font(.title2)
                            @unknown default:
                                Image(systemName: "person.fill")
                                    .foregroundColor(Theme.Colors.highlight)
                                    .font(.title2)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .background(Circle().fill(Theme.Colors.surface.opacity(0.6)))

                        Text(writer.tag)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.Colors.surface.opacity(0.8))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // Device-specific grid columns
    private var gridColumns: [GridItem] {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad: 3 columns for better use of space
            return [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ]
        } else {
            // iPhone: 2 columns for optimal readability
            return [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ]
        }
        #else
        // macOS fallback
        return [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
        #endif
    }
    
    // Device-specific card image dimensions
    private var cardImageWidth: CGFloat {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad: Fixed width for consistent grid
            return 160
        } else {
            // iPhone: Use flexible width based on screen size
            let screenWidth = UIScreen.main.bounds.width
            let padding: CGFloat = 16 * 3 // left + right + middle spacing
            let cardPadding: CGFloat = 12 * 2 * 2 // 2 cards with padding on each side
            return (screenWidth - padding - cardPadding) / 2
        }
        #else
        // macOS fallback
        return 160
        #endif
    }
    
    private var cardImageHeight: CGFloat {
        // Maintain 2:3 aspect ratio (portrait) for all actor photos
        return cardImageWidth * 1.5
    }

    private func castView(cast: [MovieRole]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Device-specific grid layouts
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(cast) { role in
                    Button(action: {
                        print("🎬 MainView: User tapped actor button")
                        print("   Role ID: '\(role.id)'")
                        print("   Role Tag (Actor Name): '\(role.tag)'")
                        print("   Role Role (Character): '\(role.role ?? "N/A")'")

                        // Store in persistent store first
                        actorNameStore.storedActorName = role.tag

                        // Set both backup and primary actor name to prevent state loss during polling
                        pendingActorName = role.tag
                        selectedActorName = role.tag
                        showingActorDetail = true

                        print("   pendingActorName set to: '\(pendingActorName)'")
                        print("   selectedActorName set to: '\(selectedActorName)'")
                        print("   storedActorName set to: '\(actorNameStore.storedActorName)'")
                        print("   showingActorDetail set to: \(showingActorDetail)")
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            AsyncImage(url: thumbnailURL(for: role.thumb)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: cardImageWidth, height: cardImageHeight)
                                        .clipped()
                                case .failure(_):
                                    Rectangle()
                                        .foregroundColor(Theme.Colors.surface.opacity(0.85))
                                        .frame(width: cardImageWidth, height: cardImageHeight)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .foregroundColor(Theme.Colors.highlight)
                                                .font(.system(size: 32))
                                        )
                                case .empty:
                                    Rectangle()
                                        .foregroundColor(Theme.Colors.surface.opacity(0.85))
                                        .frame(width: cardImageWidth, height: cardImageHeight)
                                        .overlay(
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.primaryAccent))
                                        )
                                @unknown default:
                                    Rectangle()
                                        .foregroundColor(Theme.Colors.surface.opacity(0.85))
                                        .frame(width: cardImageWidth, height: cardImageHeight)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .foregroundColor(Theme.Colors.highlight)
                                                .font(.system(size: 32))
                                        )
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(role.tag)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Theme.Colors.text)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                if let character = role.role {
                                    Text(character)
                                        .font(.caption)
                                        .foregroundColor(Theme.Colors.highlight)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Theme.Colors.surface.opacity(0.92))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Theme.Colors.highlight.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $showingActorDetail, onDismiss: {
            print("🎭 MainView: Sheet dismissed, clearing actor names")
            selectedActorName = ""
            pendingActorName = ""
            actorNameStore.storedActorName = ""
        }) {
            ActorDetailView(
                actorName: {
                    // Use primary state first, then backup, then persistent store
                    let actorNameToUse = !selectedActorName.isEmpty ? selectedActorName :
                                        !pendingActorName.isEmpty ? pendingActorName :
                                        actorNameStore.storedActorName
                    print("🎭 MainView: Presenting sheet with actor name: '\(actorNameToUse)'")
                    print("   selectedActorName: '\(selectedActorName)'")
                    print("   pendingActorName: '\(pendingActorName)'")
                    print("   storedActorName: '\(actorNameStore.storedActorName)'")
                    return actorNameToUse
                }(),
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

    // Helper functions for URLs
    private func artURL(for artPath: String?) -> URL? {
        guard let artPath = artPath else { return nil }

        // If it's already a full URL (like metadata-static.plex.tv), use it directly
        if artPath.hasPrefix("http://") || artPath.hasPrefix("https://") {
            return URL(string: artPath)
        }

        // Otherwise, construct local server URL with auth token
        let urlString = "http://\(plexService.settings.serverIP):32400\(artPath)?X-Plex-Token=\(plexService.settings.plexToken)"
        return URL(string: urlString)
    }

    private func posterURL(for thumbPath: String?) -> URL? {
        guard let thumbPath = thumbPath else { return nil }

        // If it's already a full URL (like metadata-static.plex.tv), use it directly
        if thumbPath.hasPrefix("http://") || thumbPath.hasPrefix("https://") {
            return URL(string: thumbPath)
        }

        // Otherwise, construct local server URL with auth token
        let urlString = "http://\(plexService.settings.serverIP):32400\(thumbPath)?X-Plex-Token=\(plexService.settings.plexToken)"
        return URL(string: urlString)
    }

    private func thumbnailURL(for thumbPath: String?) -> URL? {
        guard let thumbPath = thumbPath else { return nil }

        // If it's already a full URL (like metadata-static.plex.tv), use it directly
        if thumbPath.hasPrefix("http://") || thumbPath.hasPrefix("https://") {
            return URL(string: thumbPath)
        }

        // Otherwise, construct local server URL with auth token
        let urlString = "http://\(plexService.settings.serverIP):32400\(thumbPath)?X-Plex-Token=\(plexService.settings.plexToken)"
        return URL(string: urlString)
    }

    private func formatTime(_ milliseconds: Int) -> String {
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

    private func loadMovieMetadata() {
        let videoSessions = plexService.activeVideoSessions
        guard plexService.selectedSessionIndex < videoSessions.count else {
            print("⚠️ MainView: selectedSessionIndex \(plexService.selectedSessionIndex) is out of bounds for \(videoSessions.count) sessions")
            return
        }

        let currentSession = videoSessions[plexService.selectedSessionIndex]
        print("🎬 MainView: Loading metadata for session \(plexService.selectedSessionIndex): \(currentSession.title ?? "Unknown")")

        // Cancel any existing metadata loading task
        metadataTask?.cancel()

        isLoading = true
        errorMessage = nil

        metadataTask = Task {
            do {
                let response = try await plexService.getMovieMetadata(ratingKey: currentSession.id)

                // Check if task was cancelled
                if Task.isCancelled {
                    print("🔄 MainView: Metadata loading task was cancelled")
                    return
                }

                await MainActor.run {
                    self.movieMetadata = response.mediaContainer.video?.first
                    if let movie = self.movieMetadata {
                        print("🎬 Movie loaded: \(movie.title ?? "Unknown")")
                        if movie.ultraBlurColors != nil {
                            print("🎨 UltraBlurColors found!")
                        } else {
                            print("❌ No UltraBlurColors in movie data")
                        }
                    }
                    self.isLoading = false
                }

            } catch {
                // Don't show errors for cancelled tasks
                if !Task.isCancelled {
                    await MainActor.run {
                        print("❌ MainView: Error loading movie metadata: \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                        self.isLoading = false
                    }
                } else {
                    print("🔄 MainView: Metadata loading was cancelled")
                }
            }
        }
    }

     private func createGradientBackground(colors: UltraBlurColors) -> some View {
        print("🎨 Ultra Blur Colors received:")
        print("  topLeft: \(colors.topLeft ?? "nil")")
        print("  topRight: \(colors.topRight ?? "nil")")
        print("  bottomLeft: \(colors.bottomLeft ?? "nil")")
        print("  bottomRight: \(colors.bottomRight ?? "nil")")

        let topLeft = Color(hex: colors.topLeft ?? "000000")
        let topRight = Color(hex: colors.topRight ?? "000000")
        let bottomLeft = Color(hex: colors.bottomLeft ?? "000000")
        let bottomRight = Color(hex: colors.bottomRight ?? "000000")

        return LinearGradient(
            colors: [
                topLeft.opacity(0.4),
                topRight.opacity(0.2),
                bottomLeft.opacity(0.2),
                bottomRight.opacity(0.4)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Helper function to safely format rating values
    private func formatRating(_ value: Double) -> String {
        if value.isNaN || value.isInfinite {
            return "N/A"
        }
        return String(format: "%.1f", value)
    }
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
            ForEach(Array(createRows()), id: \.0) { rowIndex, rowItems in
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
        
        // For simplicity, we'll put 3-4 items per row
        // This works well for genre/country pills
        let itemsPerRow = 3
        
        for item in items {
            currentRow.append(item)
            
            if currentRow.count == itemsPerRow {
                rows.append((rowIndex, currentRow))
                currentRow = []
                rowIndex += 1
            }
        }
        
        // Add remaining items
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

#Preview {
    MainView(plexService: PlexService())
}

// Custom modifier to conditionally apply frame dimensions  
