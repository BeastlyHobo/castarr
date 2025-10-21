//
//  ActorDetailView.swift
//  RoleCall
//
//  Created by Eric on 1/27/25.
//

import SwiftUI

struct ActorDetailView: View {
    let actorName: String
    let imdbService: IMDbService
    let movieYear: Int? // Year of the movie being watched
    let movieIMDbID: String? // IMDb ID of the current movie for context
    let movieMetadata: MovieMetadata? // Full Plex movie metadata with ratings
    @Environment(\.dismiss) private var dismiss

    @State private var actorDetails: IMDbPersonDetails?
    @State private var movieCredits: IMDbPersonMovieCredits?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingActorPosterDetail = false
    @State private var selectedMovie: IMDbMovieCredit?

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color.black.opacity(0.1), Color.gray.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading actor details...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)

                        Text("Error Loading Details")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(errorMessage)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Try Again") {
                            loadActorData()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    scrollContent
                }
            }
            .navigationTitle(actorName)
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
        .onAppear {
            print("🎭 ActorDetailView.onAppear called")
            print("   Initial actorName: '\(actorName)'")
            print("   ActorName length: \(actorName.count)")
            print("   ActorName trimmed: '\(actorName.trimmingCharacters(in: .whitespacesAndNewlines))'")
            loadActorData()
        }
        .sheet(isPresented: $showingActorPosterDetail) {
            if let details = actorDetails {
                ActorPosterDetailView(
                    posterURL: imdbService.profileImageURL(path: details.profilePath, size: .original),
                    actorName: details.name
                )
            }
        }
        .sheet(item: $selectedMovie) { movie in
            // Try to find matching Plex metadata for this movie
            let matchingPlexMetadata = findMatchingPlexMetadata(for: movie.id)
            MovieDetailView(
                movieId: movie.id,
                imdbService: imdbService,
                plexMovieMetadata: matchingPlexMetadata
            )
        }
    }

    @ViewBuilder
    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let details = actorDetails {
                    actorInfoSection(details: details)

                    if let credits = movieCredits {
                        filmographySection(credits: credits)
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func actorInfoSection(details: IMDbPersonDetails) -> some View {
        VStack(spacing: 20) {
            // Profile Photo
            Button(action: {
                showingActorPosterDetail = true
            }) {
                AsyncImage(url: imdbService.profileImageURL(path: details.profilePath, size: .w500)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .foregroundColor(.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray.opacity(0.6))
                                .font(.system(size: 64))
                        )
                }
                .frame(width: 200, height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 8)
            }
            .buttonStyle(PlainButtonStyle())

            // Basic Info
            VStack(spacing: 12) {
                Text(details.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                if let knownFor = details.knownForDepartment {
                    Text("\(knownFor.capitalized)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }

                // Personal Details
                VStack(alignment: .leading, spacing: 8) {
                    if let birthday = details.birthday {
                        detailRow(title: "Born", value: formatDate(birthday))

                        // Add age information
                        if let ageString = formatAgeString(birthday: birthday, deathday: details.deathday) {
                            detailRow(title: "Age", value: ageString)
                        }
                    }

                    if let deathday = details.deathday {
                        detailRow(title: "Died", value: formatDate(deathday))
                    }

                    if let birthPlace = details.placeOfBirth {
                        detailRow(title: "Birthplace", value: birthPlace)
                    }
                }
                .padding()
                .background(.thickMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Biography
                if let biography = details.biography, !biography.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Biography")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(biography)
                            .font(.body)
                            .lineSpacing(4)
                    }
                    .padding()
                    .background(.thickMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func getFilteredTopMovies(from credits: IMDbPersonMovieCredits) -> [IMDbMovieCredit] {
        let allMovies = credits.cast
        let filteredMovies = allMovies.filter { movie in
            // Filter out the current movie if we know its IMDb ID
            if let currentMovieID = movieIMDbID {
                let shouldExclude = movie.id == currentMovieID
                if shouldExclude {
                    print("🎬 Filtering out current movie '\(movie.title)' (ID: \(movie.id)) from Known For list")
                }
                return !shouldExclude
            }
            return true
        }
        
        print("🎬 Known For: Showing \(min(filteredMovies.count, 10)) of \(filteredMovies.count) movies (filtered from \(allMovies.count) total)")
        
        return Array(filteredMovies
            .sorted { $0.popularity > $1.popularity }
            .prefix(10))
    }

    @ViewBuilder
    private func filmographySection(credits: IMDbPersonMovieCredits) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Known For")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            let topMovies = getFilteredTopMovies(from: credits)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 16) {
                ForEach(topMovies, id: \.id) { movie in
                    movieCard(movie: movie)
                }
            }
        }
    }

    @ViewBuilder
    private func movieCard(movie: IMDbMovieCredit) -> some View {
        Button(action: {
            selectedMovie = movie
        }) {
            VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: imdbService.posterImageURL(path: movie.posterPath)) { image in
                image
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .foregroundColor(.gray.opacity(0.3))
                    .aspectRatio(2/3, contentMode: .fit)
                    .overlay(
                        Image(systemName: "film")
                            .foregroundColor(.gray.opacity(0.6))
                            .font(.title)
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(movie.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let character = movie.character, !character.isEmpty {
                    Text("as \(character)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                if let releaseDate = movie.releaseDate {
                    Text(String(releaseDate.prefix(4))) // Just the year
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Rating stars
                if movie.voteAverage > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(movie.voteAverage / 2) ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                        Text(formatRating(movie.voteAverage))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            }
            .padding(8)
            .background(.thickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func findMatchingPlexMetadata(for imdbMovieId: String) -> MovieMetadata? {
        // If the selected movie ID matches the current movie's IMDb ID, return the current movie metadata
        if let currentMovieIMDbID = movieIMDbID, currentMovieIMDbID == imdbMovieId {
            return movieMetadata
        }
        
        // For now, we can't find other movies' Plex metadata without a service reference
        // In a future enhancement, we could pass a PlexService reference to look up other movies
        return nil
    }

    private func loadActorData() {
        // Validate that we have a non-empty actor name
        guard !actorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "No actor name provided"
            isLoading = false
            return
        }

        print("🎭 ActorDetailView: Loading data for '\(actorName)'")

        isLoading = true
        errorMessage = nil

        Task {
            await loadActorDataWithRetry()
        }
    }

    private func loadActorDataWithRetry(retryCount: Int = 0) async {
        let maxRetries = 3

        do {
            // First, search for the actor (with movie context if available)
            let searchResponse = try await imdbService.searchPerson(name: actorName, imdbMovieID: movieIMDbID)

            guard let firstResult = searchResponse.results.first else {
                await MainActor.run {
                    self.errorMessage = "Actor not found in IMDb database"
                    self.isLoading = false
                }
                return
            }

            // Get detailed information
            async let detailsTask = imdbService.getPersonDetails(nameID: firstResult.id)
            async let creditsTask = imdbService.getPersonMovieCredits(nameID: firstResult.id)

            let (details, credits) = try await (detailsTask, creditsTask)

            await MainActor.run {
                self.actorDetails = details
                self.movieCredits = credits
                self.isLoading = false
            }

        } catch {
            if retryCount < maxRetries {
                print("🔄 Actor detail load failed (attempt \(retryCount + 1)/\(maxRetries + 1)), retrying in \(retryCount + 1) seconds...")

                // Progressive delay: 1s, 2s, 3s
                try? await Task.sleep(nanoseconds: UInt64((retryCount + 1) * 1_000_000_000))

                // Retry
                await loadActorDataWithRetry(retryCount: retryCount + 1)
            } else {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .long
            return formatter.string(from: date)
        }

        return dateString
    }

    private func calculateAge(from birthday: String, to targetYear: Int? = nil) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let birthDate = formatter.date(from: birthday) else { return nil }

        let calendar = Calendar.current
        let birthYear = calendar.component(.year, from: birthDate)

        if let targetYear = targetYear {
            return targetYear - birthYear
        } else {
            // Calculate current age
            let now = Date()
            let currentYear = calendar.component(.year, from: now)
            let currentMonth = calendar.component(.month, from: now)
            let currentDay = calendar.component(.day, from: now)

            let birthMonth = calendar.component(.month, from: birthDate)
            let birthDay = calendar.component(.day, from: birthDate)

            var age = currentYear - birthYear

            // Adjust if birthday hasn't occurred this year yet
            if currentMonth < birthMonth || (currentMonth == birthMonth && currentDay < birthDay) {
                age -= 1
            }

            return age
        }
    }

    private func calculateAgeAtDeath(birthday: String, deathday: String) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        guard let birthDate = formatter.date(from: birthday),
              let deathDate = formatter.date(from: deathday) else { return nil }

        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year, .month, .day], from: birthDate, to: deathDate)

        return ageComponents.year
    }

    private func formatAgeString(birthday: String, deathday: String?) -> String? {
        let isDeceased = deathday != nil

        // Calculate the appropriate age for display
        let displayAge: Int?
        let currentStatus: String

        if isDeceased {
            // For deceased persons, calculate age at death
            displayAge = calculateAgeAtDeath(birthday: birthday, deathday: deathday!)
            currentStatus = "deceased"
        } else {
            // For living persons, calculate current age
            displayAge = calculateAge(from: birthday)
            currentStatus = "currently"
        }

        guard let age = displayAge else { return nil }

        if let movieYear = movieYear,
           let ageAtMovie = calculateAge(from: birthday, to: movieYear) {
            return "\(ageAtMovie) (then), \(age) (\(currentStatus))"
        } else {
            return "\(age) (\(currentStatus))"
        }
    }

    // Helper function to safely format rating values
    private func formatRating(_ value: Double) -> String {
        if value.isNaN || value.isInfinite {
            return "N/A"
        }
        return String(format: "%.1f", value)
    }
}

// Actor poster detail view for expanded poster display
struct ActorPosterDetailView: View {
    let posterURL: URL?
    let actorName: String
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
                                .foregroundColor(.gray.opacity(0.3))
                                .aspectRatio(2/3, contentMode: .fit)
                                .overlay(
                                    VStack {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 48))
                                            .foregroundColor(.gray.opacity(0.6))
                                        
                                        ProgressView()
                                            .scaleEffect(1.5)
                                            .padding(.top, 8)
                                    }
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
            .navigationTitle(actorName)
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