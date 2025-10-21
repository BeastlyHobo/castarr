//
//  MovieDetailView.swift
//  RoleCall
//
//  Created by AI Assistant on 11/21/24.
//

import SwiftUI

struct MovieDetailView: View {
    let movieId: String
    let imdbService: IMDbService
    let plexMovieMetadata: MovieMetadata? // Optional Plex metadata with ratings
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var movieDetails: IMDbMovieDetails?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingPosterDetail = false
    
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
                    ProgressView("Loading movie details...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        
                        Text("Error Loading Movie")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(errorMessage)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Try Again") {
                            loadMovieData()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    scrollContent
                }
            }
            .navigationTitle(plexMovieMetadata?.title ?? movieDetails?.displayTitle ?? "Movie Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            print("🎬 Loading movie details for ID: \(movieId)")
            loadMovieData()
        }
        .sheet(isPresented: $showingPosterDetail) {
            if let details = movieDetails {
                PosterDetailView(
                    posterURL: imdbService.posterImageURL(path: details.posterPath, size: .original),
                    movieTitle: plexMovieMetadata?.title ?? details.displayTitle
                )
            }
        }
    }
    
    @ViewBuilder
    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let details = movieDetails {
                    movieInfoSection(details: details)
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func movieInfoSection(details: IMDbMovieDetails) -> some View {
        let posterURL = imdbService.posterImageURL(path: details.posterPath, size: .w500)
        let _ = print("🔍 DEBUG: Loading poster image from URL: \(posterURL?.absoluteString ?? "nil")")
        
        VStack(spacing: 32) {
            // Movie Poster - Centered
            HStack {
                Spacer()
                Button(action: {
                    showingPosterDetail = true
                }) {
                    AsyncImage(url: posterURL) { image in
                        image
                            .resizable()
                            .aspectRatio(2/3, contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 300)
                    } placeholder: {
                        Rectangle()
                            .foregroundColor(.gray.opacity(0.3))
                            .aspectRatio(2/3, contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 300)
                            .overlay(
                                Image(systemName: "film")
                                    .foregroundColor(.gray.opacity(0.6))
                                    .font(.system(size: 48))
                            )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 10)
                }
                .buttonStyle(PlainButtonStyle())
                Spacer()
            }
            
            // Movie Title
            Text(plexMovieMetadata?.title ?? details.displayTitle)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Basic Info Card
            VStack(alignment: .leading, spacing: 16) {
                // Year and Runtime
                HStack(spacing: 8) {
                    if let year = plexMovieMetadata?.year ?? Int(details.releaseYear ?? "") {
                        Text("\(year)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let runtime = details.formattedRuntime {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(runtime)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Ratings - prefer Plex ratings first, then IMDb
                ratingsView(plexRatings: plexMovieMetadata?.ratings,
                           imdbRating: details.voteAverage,
                           imdbVoteCount: details.voteCount)
            }
            .padding(20)
            .background(.thickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Tagline
                if let tagline = details.tagline, !tagline.isEmpty {
                    Text(tagline)
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Material.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Plot/Overview - prefer Plex summary first, then IMDb overview
                let plotText = plexMovieMetadata?.summary ?? details.overview
                if let plot = plotText, !plot.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Plot")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(plot)
                            .font(.body)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .background(.thickMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Genres
                if let genres = details.genres, !genres.isEmpty {
                    genresView(genres: genres)
                }
                
                // Countries (from Plex metadata)
                if let countries = plexMovieMetadata?.countries, !countries.isEmpty {
                    countriesView(countries: countries)
                }
            }
        }
    
    @ViewBuilder
    private func ratingsView(plexRatings: [MovieRating]?, imdbRating: Double, imdbVoteCount: Int) -> some View {
        // Show Plex ratings if available, otherwise fall back to IMDb rating
        if let ratings = plexRatings, !ratings.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(ratings, id: \.computedId) { rating in
                    if let value = rating.value, value > 0 {
                        HStack(spacing: 8) {
                            // Show rating source image/icon
                            if let image = rating.image {
                                if image.contains("imdb") {
                                    Text("IMDb")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.yellow)
                                } else if image.contains("rottentomatoes") {
                                    Text(image.contains("ripe") ? "🍅" : "🚫")
                                        .font(.caption)
                                    Text("RT")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                } else if image.contains("themoviedb") {
                                    Text("TMDB")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                } else {
                                    Text(rating.type?.capitalized ?? "Rating")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // Show star rating for values that make sense as ratings
                            if value <= 10 {
                                HStack(spacing: 2) {
                                    ForEach(0..<5) { index in
                                        Image(systemName: index < Int(value / 2) ? "star.fill" : "star")
                                            .font(.caption)
                                            .foregroundColor(.yellow)
                                    }
                                }
                                
                                Text("\(String(format: "%.1f", value))/10")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                // For percentage ratings like RT
                                Text("\(String(format: "%.0f", value))%")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let count = rating.count, count > 0 {
                                Text("(\(count) votes)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        } else if imdbRating > 0 {
            // Fall back to IMDb rating
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < Int(imdbRating / 2) ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                
                Text("\(String(format: "%.1f", imdbRating))/10")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if imdbVoteCount > 0 {
                    Text("(\(imdbVoteCount) votes)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func genresView(genres: [IMDbGenre]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Genres")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(genres) { genre in
                    Text(genre.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(20)
        .background(.thickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func countriesView(countries: [MovieCountry]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Countries")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(countries) { country in
                    Text(country.tag)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.green.opacity(0.2))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(20)
        .background(.thickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func loadMovieData() {
        Task {
            await loadMovieDataWithRetry()
        }
    }
    
    private func loadMovieDataWithRetry(retryCount: Int = 0) async {
        let maxRetries = 3
        
        do {
            let details = try await imdbService.getMovieDetails(titleID: movieId)
            
            await MainActor.run {
                print("🔍 DEBUG: Setting movieDetails - Title: '\(details.title)', displayTitle: '\(details.displayTitle)'")
                print("🔍 DEBUG: VoteAverage: \(details.voteAverage), VoteCount: \(details.voteCount)")
                print("🔍 DEBUG: Genres: \(details.genres?.map { "\($0.name) (id: \($0.id))" } ?? ["none"])")
                self.movieDetails = details
                self.isLoading = false
            }
            
        } catch {
            print("❌ Movie detail load error for \(movieId): \(error)")
            if retryCount < maxRetries {
                print("🔄 Movie detail load failed (attempt \(retryCount + 1)/\(maxRetries + 1)), retrying in \(retryCount + 1) seconds...")
                
                // Progressive delay: 1s, 2s, 3s
                try? await Task.sleep(nanoseconds: UInt64((retryCount + 1) * 1_000_000_000))
                
                // Retry
                await loadMovieDataWithRetry(retryCount: retryCount + 1)
            } else {
                print("❌ All retries failed for movie \(movieId), showing error")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}