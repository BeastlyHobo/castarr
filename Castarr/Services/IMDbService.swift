//
//  IMDbService.swift
//  RoleCall
//
//  Created by Eric on 7/30/25.
//

import Foundation

@MainActor
class IMDbService: ObservableObject {
    // Updated base URL per imdbapi.dev migration
    private let baseURL = "https://api.imdbapi.dev"
    private let session: URLSession

    // In-memory cache for responses
    private var cache: [String: (data: Any, timestamp: Date)] = [:]
    private let cacheTimeout: TimeInterval = 3600 // 1 hour cache
    private let maxCacheSize = 50

    init() {
        // Configure URLSession for REST requests
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 4
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30

        self.session = URLSession(configuration: config)
    }

    enum IMDbError: Error, LocalizedError {
        case invalidURL
        case noData
        case invalidIMDbID
        case apiError(String)
        case decodingError(Error)
        case networkError(Error)
        case httpError(Int)
        case actorNotFound

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid IMDb API URL"
            case .noData:
                return "No data received from IMDb API"
            case .invalidIMDbID:
                return "Invalid or missing IMDb ID"
            case .apiError(let message):
                return "IMDb API error: \(message)"
            case .decodingError(let error):
                return "Failed to decode IMDb data: \(error.localizedDescription)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .httpError(let code):
                return "HTTP error: \(code)"
            case .actorNotFound:
                return "Actor not found in IMDb database"
            }
        }
    }

    // MARK: - Public Methods

    /// Search for a person by name (returns multiple potential matches)
    /// Note: This method now requires additional context since the IMDb search API is broken
    func searchPerson(name: String, imdbMovieID: String? = nil) async throws -> IMDbPersonSearchResponse {
        print("🔍 IMDb: Searching for person '\(name)'")
        
        // If we have a movie IMDb ID, search within that movie's cast
        if let movieID = imdbMovieID {
            print("🎬 Using movie context: \(movieID)")
            let actor = try await findActorInMovie(actorName: name, imdbMovieID: movieID)
            if let actor = actor {
                return IMDbPersonSearchResponse(results: [actor])
            }
        }
        
        // Fallback: Without working search API, we cannot find actors by name alone
        // This should be handled by getting IMDb IDs from Plex metadata
        throw IMDbError.actorNotFound
    }

    /// Get detailed information about a person by IMDb name ID (nm0000001 format)
    func getPersonDetails(nameID: String) async throws -> IMDbPersonDetails {
        print("🔍 IMDb: Getting person details for '\(nameID)'")

        // Check cache first
        let cacheKey = "person_\(nameID)"
        if let cached = cache[cacheKey] as? (data: IMDbPersonDetails, timestamp: Date) {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheTimeout {
                print("🗄️ Using cached person details for \(nameID)")
                return cached.data
            }
        }

        let personInfo = try await fetchPersonDetails(nameID: nameID)

        // Cache the result
        cache[cacheKey] = (data: personInfo, timestamp: Date())
        cleanupCache()

        return personInfo
    }

    /// Get movie credits for a person by IMDb name ID
    func getPersonMovieCredits(nameID: String) async throws -> IMDbPersonMovieCredits {
        print("🔍 IMDb: Getting movie credits for '\(nameID)'")

        // Check cache first
        let cacheKey = "credits_\(nameID)"
        if let cached = cache[cacheKey] as? (data: IMDbPersonMovieCredits, timestamp: Date) {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheTimeout {
                print("🗄️ Using cached movie credits for \(nameID)")
                return cached.data
            }
        }

        let knownForResponse = try await fetchPersonKnownFor(nameID: nameID)
        let movieCredits = convertToMovieCredits(knownForResponse)

        // Cache the result
        cache[cacheKey] = (data: movieCredits, timestamp: Date())
        cleanupCache()

        return movieCredits
    }
    
    /// Get images for a person by IMDb name ID
    func getPersonImages(nameID: String) async throws -> [APIImage] {
        print("🔍 IMDb: Getting images for '\(nameID)'")
        
        // Check cache first
        let cacheKey = "images_\(nameID)"
        if let cached = cache[cacheKey] as? (data: [APIImage], timestamp: Date) {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheTimeout {
                print("🗄️ Using cached images for \(nameID)")
                return cached.data
            }
        }
        
        guard let url = URL(string: "\(baseURL)/names/\(nameID)/images?pageSize=50") else {
            throw IMDbError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("RoleCall/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw IMDbError.httpError(httpResponse.statusCode)
        }
        
        let imagesResponse = try JSONDecoder().decode(APIImagesResponse.self, from: data)
        
        // Cache the result
        cache[cacheKey] = (data: imagesResponse.images, timestamp: Date())
        cleanupCache()
        
        return imagesResponse.images
    }
    
    /// Get relationships for a person by IMDb name ID
    func getPersonRelationships(nameID: String) async throws -> [APIRelationship] {
        print("🔍 IMDb: Getting relationships for '\(nameID)'")
        
        // Check cache first
        let cacheKey = "relationships_\(nameID)"
        if let cached = cache[cacheKey] as? (data: [APIRelationship], timestamp: Date) {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheTimeout {
                print("🗄️ Using cached relationships for \(nameID)")
                return cached.data
            }
        }
        
        guard let url = URL(string: "\(baseURL)/names/\(nameID)/relationships") else {
            throw IMDbError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("RoleCall/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw IMDbError.httpError(httpResponse.statusCode)
        }
        
        let relationshipsResponse = try JSONDecoder().decode(APIRelationshipsResponse.self, from: data)
        
        // Cache the result
        cache[cacheKey] = (data: relationshipsResponse.relationships, timestamp: Date())
        cleanupCache()
        
        return relationshipsResponse.relationships
    }
    
    /// Get trivia for a person by IMDb name ID
    func getPersonTrivia(nameID: String) async throws -> [APITriviaItem] {
        print("🔍 IMDb: Getting trivia for '\(nameID)'")
        
        // Check cache first
        let cacheKey = "trivia_\(nameID)"
        if let cached = cache[cacheKey] as? (data: [APITriviaItem], timestamp: Date) {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheTimeout {
                print("🗄️ Using cached trivia for \(nameID)")
                return cached.data
            }
        }
        
        guard let url = URL(string: "\(baseURL)/names/\(nameID)/trivia?pageSize=50") else {
            throw IMDbError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("RoleCall/1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw IMDbError.httpError(httpResponse.statusCode)
        }
        
        let triviaResponse = try JSONDecoder().decode(APITriviaResponse.self, from: data)
        
        // Cache the result
        cache[cacheKey] = (data: triviaResponse.trivia, timestamp: Date())
        cleanupCache()
        
        return triviaResponse.trivia
    }

    /// Get detailed information about a movie by IMDb title ID (tt0000001 format)
    func getMovieDetails(titleID: String) async throws -> IMDbMovieDetails {
        print("🔍 IMDb: Getting movie details for '\(titleID)'")

        // Check cache first
        let cacheKey = "movie_\(titleID)"
        if let cached = cache[cacheKey] as? (data: IMDbMovieDetails, timestamp: Date) {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheTimeout {
                print("🗄️ Using cached movie details for \(titleID)")
                return cached.data
            }
        }

        let movieDetails = try await fetchMovieDetails(titleID: titleID)

        // Cache the result
        cache[cacheKey] = (data: movieDetails, timestamp: Date())
        cleanupCache()

        return movieDetails
    }

    /// Search for a movie by title (for future use)
    func searchMovie(title: String, year: Int? = nil) async throws -> IMDbMovieSearchResponse {
        print("🔍 IMDb: Searching for movie '\(title)'")

        // New API: /search/titles?query=...&limit=10
        guard let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/search/titles?query=\(encodedTitle)&limit=10") else {
            throw IMDbError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("RoleCall/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw IMDbError.httpError(httpResponse.statusCode)
        }

        let searchResponse = try JSONDecoder().decode(SearchTitlesResponse.self, from: data)
        return IMDbMovieSearchResponse(results: searchResponse.titles.map { title in
            IMDbMovieSearchResult(
                id: title.id,
                title: title.primaryTitle ?? title.originalTitle ?? "Unknown Title",
                releaseDate: title.startYear != nil ? "\(title.startYear!)" : nil,
                overview: title.plot,
                posterPath: title.primaryImage?.url,
                voteAverage: title.rating?.aggregateRating ?? 0.0,
                popularity: 0.0 // Not available in IMDb API
            )
        })
    }

    /// Generate full URL for profile image
    func profileImageURL(path: String?, size: IMDbImageSize = .w500) -> URL? {
        guard let path = path else { return nil }
        return URL(string: path) // IMDb provides full URLs
    }

    /// Generate full URL for poster image
    func posterImageURL(path: String?, size: IMDbImageSize = .w342) -> URL? {
        guard let path = path else { return nil }
        return URL(string: path) // IMDb provides full URLs
    }

    // MARK: - Private Methods

    /// Find an actor by name within a specific movie's cast
    private func findActorInMovie(actorName: String, imdbMovieID: String) async throws -> IMDbPersonSearchResult? {
        print("🔍 Fetching credits for movie: \(imdbMovieID)")
        
        do {
            let credits = try await fetchCredits(imdbID: imdbMovieID)
            print("✅ Found \(credits.credits.count) total credits")
            
            // Log all categories to debug
            let categories = Set(credits.credits.compactMap { $0.category })
            print("📋 Categories found: \(categories.sorted())")
            
            // Log first few cast members to debug
            let castMembers: [String] = credits.credits.prefix(5).compactMap { credit in
                guard let name = credit.name else { return nil }
                return "\(name.displayName) (\(credit.category ?? "unknown"))"
            }
            print("🎬 First cast members: \(castMembers)")
            
            // Find the actor in the movie's cast - use case-insensitive matching
            let matchingActor = credits.credits.first { credit in
                guard let creditName = credit.name else { return false }
                
                let category = (credit.category ?? "").uppercased()
                let isActing = category == "ACTOR" || category == "ACTRESS" || category == "SELF"
                
                let actorNameLower = actorName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let creditNameLower = creditName.displayName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
                let nameMatches = creditNameLower.contains(actorNameLower) || 
                                 actorNameLower.contains(creditNameLower) ||
                                 creditNameLower == actorNameLower
                
                if nameMatches {
                    print("🎯 Potential match found: '\(creditName.displayName)' (category: \(category), isActing: \(isActing))")
                }
                
                return isActing && nameMatches
            }
            
            guard let actor = matchingActor, let actorName = actor.name else {
                print("❌ No matching actor found for '\(actorName)' in movie \(imdbMovieID)")
                return nil
            }
            
            print("✅ Found actor: \(actorName.displayName) (ID: \(actorName.id))")
            
            return IMDbPersonSearchResult(
                id: actorName.id,
                name: actorName.displayName,
                profilePath: actorName.primaryImage?.url,
                knownForDepartment: actor.category?.uppercased() == "ACTRESS" ? "Acting" : "Acting",
                popularity: 0.0,
                knownFor: []
            )
        } catch {
            print("❌ Error fetching credits: \(error)")
            throw error
        }
    }

    private func fetchPersonDetails(nameID: String) async throws -> IMDbPersonDetails {
        guard let url = URL(string: "\(baseURL)/names/\(nameID)") else {
            throw IMDbError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("RoleCall/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw IMDbError.httpError(httpResponse.statusCode)
        }

        let personInfo = try JSONDecoder().decode(APIName.self, from: data)

        return IMDbPersonDetails(
            id: personInfo.id,
            name: personInfo.displayName,
            alternativeNames: personInfo.alternativeNames,
            biography: personInfo.biography,
            birthday: formatDate(personInfo.birthDate),
            deathday: formatDate(personInfo.deathDate),
            placeOfBirth: personInfo.birthLocation,
            profilePath: personInfo.primaryImage?.url,
            knownForDepartment: personInfo.primaryProfessions?.first,
            popularity: 0.0, // Not available in IMDb API
            heightCm: personInfo.heightCm,
            birthName: personInfo.birthName,
            meterRanking: personInfo.meterRanking.map { apiRanking in
                MeterRanking(
                    currentRank: apiRanking.currentRank,
                    changeDirection: apiRanking.changeDirection,
                    difference: apiRanking.difference
                )
            }
        )
    }

    private func fetchPersonKnownFor(nameID: String) async throws -> APIFilmographyResponse {
        print("🔍 Fetching filmography for: \(nameID)")
        
        // Fetch all categories: ACTOR, ACTRESS, DIRECTOR, WRITER, PRODUCER, SELF
        // Using pageSize=50 to get a good sample of their work
        guard let url = URL(string: "\(baseURL)/names/\(nameID)/filmography?pageSize=50") else {
            print("❌ Invalid URL for filmography")
            throw IMDbError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("RoleCall/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Filmography API response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Error response: \(responseString.prefix(200))")
                    }
                    throw IMDbError.httpError(httpResponse.statusCode)
                }
            }

            // Try to decode and log on error
            do {
                let decoded = try JSONDecoder().decode(APIFilmographyResponse.self, from: data)
                print("✅ Successfully decoded \(decoded.credits.count) filmography credits")
                return decoded
            } catch {
                print("❌ Filmography decoding error: \(error)")
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("   Missing key: '\(key.stringValue)' at \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .typeMismatch(let type, let context):
                        print("   Type mismatch for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                        print("   Expected: \(type)")
                    case .valueNotFound(let type, let context):
                        print("   Value not found for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .dataCorrupted(let context):
                        print("   Data corrupted at \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                        print("   Debug: \(context.debugDescription)")
                    @unknown default:
                        print("   Unknown decoding error")
                    }
                }
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 Response data (first 1000 chars): \(responseString.prefix(1000))")
                }
                throw IMDbError.decodingError(error)
            }
        } catch let error as IMDbError {
            throw error
        } catch {
            print("❌ Network error fetching filmography: \(error)")
            throw IMDbError.networkError(error)
        }
    }

    private func fetchCredits(imdbID: String) async throws -> APICreditsResponse {
        // New API uses pageSize (camelCase)
        guard let url = URL(string: "\(baseURL)/titles/\(imdbID)/credits?pageSize=50") else {
            print("❌ Invalid URL for credits: \(baseURL)/titles/\(imdbID)/credits")
            throw IMDbError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("RoleCall/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Credits API response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("❌ Error response: \(responseString.prefix(200))")
                    }
                    throw IMDbError.httpError(httpResponse.statusCode)
                }
            }

            // Try to decode and log on error
            do {
                let decoded = try JSONDecoder().decode(APICreditsResponse.self, from: data)
                print("✅ Successfully decoded \(decoded.credits.count) credits")
                return decoded
            } catch {
                print("❌ Decoding error: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 Response data: \(responseString.prefix(500))")
                }
                throw IMDbError.decodingError(error)
            }
        } catch let error as IMDbError {
            throw error
        } catch {
            print("❌ Network error: \(error)")
            throw IMDbError.networkError(error)
        }
    }

    private func convertToMovieCredits(_ response: APIFilmographyResponse) -> IMDbPersonMovieCredits {
        print("🎬 Converting \(response.credits.count) credits to movie credits")
        
        // Separate credits into cast (acting roles) and crew (behind-the-scenes roles)
        let actingCategories = ["ACTOR", "ACTRESS", "SELF"]
        
        var castCredits: [IMDbMovieCredit] = []
        var crewCredits: [IMDbMovieCredit] = []
        
        for credit in response.credits {
            guard let title = credit.title else {
                print("⚠️ Skipping credit with no title")
                continue
            }
            
            let categoryUpper = (credit.category ?? "").uppercased()
            
            let movieCredit = IMDbMovieCredit(
                id: title.id,
                title: title.primaryTitle ?? title.originalTitle ?? "Unknown Title",
                character: credit.characters?.first,
                job: credit.category,
                releaseDate: title.startYear != nil ? "\(title.startYear!)" : nil,
                posterPath: title.primaryImage?.url,
                voteAverage: title.rating?.aggregateRating ?? 0.0,
                popularity: 0.0, // Not available
                episodeCount: credit.episodeCount
            )
            
            // Categorize as cast or crew based on the category
            if actingCategories.contains(categoryUpper) {
                castCredits.append(movieCredit)
            } else {
                crewCredits.append(movieCredit)
            }
        }
        
        print("✅ Converted to \(castCredits.count) cast credits and \(crewCredits.count) crew credits")

        return IMDbPersonMovieCredits(
            cast: castCredits,
            crew: crewCredits
        )
    }

    private func formatDate(_ apiDate: APIPrecisionDate?) -> String? {
        guard let apiDate = apiDate,
              let year = apiDate.year else { return nil }

        if let month = apiDate.month, let day = apiDate.day {
            return String(format: "%04d-%02d-%02d", year, month, day)
        } else {
            return "\(year)"
        }
    }

    private func cleanupCache() {
        if cache.count > maxCacheSize {
            // Remove oldest entries based on timestamp in the tuple value
            let sortedEntries = cache.sorted { first, second in
                first.value.timestamp < second.value.timestamp
            }
            // Keep only the most recent entries
            cache = Dictionary(uniqueKeysWithValues: Array(sortedEntries.suffix(maxCacheSize)))
        }
    }

    /// Fetch detailed movie information from IMDb API
    private func fetchMovieDetails(titleID: String) async throws -> IMDbMovieDetails {
        guard titleID.hasPrefix("tt") else {
            throw IMDbError.invalidIMDbID
        }

        guard let url = URL(string: "\(baseURL)/titles/\(titleID)") else {
            throw IMDbError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("RoleCall/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    throw IMDbError.httpError(httpResponse.statusCode)
                }
            }

            // Parse the response with new API model
            let apiResponse = try JSONDecoder().decode(APITitle.self, from: data)
            
            // Debug logging
            print("🔍 DEBUG: API Response for \(titleID):")
            print("   primaryTitle: '\(apiResponse.primaryTitle ?? "nil")'")
            print("   originalTitle: '\(apiResponse.originalTitle ?? "nil")'")
            print("   rating: \(apiResponse.rating?.aggregateRating ?? 0.0)")
            print("   plot: '\(apiResponse.plot?.prefix(50) ?? "nil")...'")
            
            // Convert runtimeSeconds (API) -> minutes for our UI
            let runtimeMinutes: Int? = {
                if let seconds = apiResponse.runtimeSeconds { return max(1, seconds / 60) }
                return nil
            }()

            return IMDbMovieDetails(
                id: apiResponse.id,
                title: apiResponse.primaryTitle ?? apiResponse.originalTitle ?? "Unknown Title",
                originalTitle: apiResponse.originalTitle,
                releaseDate: apiResponse.startYear != nil ? "\(apiResponse.startYear!)" : nil,
                runtime: runtimeMinutes,
                overview: apiResponse.plot,
                tagline: nil, // Not available in this API
                posterPath: apiResponse.primaryImage?.url,
                backdropPath: nil, // Not available in this API
                voteAverage: apiResponse.rating?.aggregateRating ?? 0.0,
                voteCount: apiResponse.rating?.voteCount ?? 0,
                popularity: 0.0, // Not available in this API
                genres: apiResponse.genres?.enumerated().map { IMDbGenre(id: $0.offset + 1, name: $0.element) },
                productionCountries: nil, // Not available in this API
                spokenLanguages: nil, // Not available in this API
                productionCompanies: nil, // Not available in this API
                budget: nil, // Not available in this API
                revenue: nil, // Not available in this API
                status: nil, // Not available in this API
                adult: apiResponse.isAdult ?? false
            )

        } catch let decodingError as DecodingError {
            print("❌ Failed to decode movie details: \(decodingError)")
            throw IMDbError.decodingError(decodingError)
        } catch {
            print("❌ Network error fetching movie details: \(error)")
            throw IMDbError.networkError(error)
        }
    }
}

// MARK: - IMDb Image Sizes
enum IMDbImageSize: String {
    case w92 = "w92"
    case w154 = "w154"
    case w185 = "w185"
    case w342 = "w342"
    case w500 = "w500"
    case w780 = "w780"
    case original = "original"
}
