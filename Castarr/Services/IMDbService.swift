//
//  IMDbService.swift
//  Castarr
//
//  Created by Eric on 7/30/25.
//  Migrated from api.imdbapi.dev to TMDB after that service shut down (July 2026).
//

import Foundation

/// Metadata enrichment service for cast, crew, and film details.
///
/// **Data source: The Movie Database (TMDB).**
///
/// The type keeps its historical `IMDbService` name because Castarr is keyed on
/// IMDb IDs: Plex reports `imdb://tt…` GUIDs, and every lookup here begins from one
/// of those IDs, resolved to a TMDB record through `/find`. TMDB is the provider;
/// IMDb IDs remain the identifier the rest of the app speaks in.
///
/// Requires a TMDB **API Read Access Token** (read-only, v4 auth), supplied at build
/// time through `Secrets.xcconfig` → `Info.plist` → `TMDB_READ_TOKEN`. When the token
/// is absent the service throws `IMDbError.missingAPIKey`; callers treat enrichment as
/// optional, so the app degrades to Plex-only data rather than failing.
@MainActor
class IMDbService: ObservableObject {
    private let baseURL = "https://api.themoviedb.org/3"
    private let imageBaseURL = "https://image.tmdb.org/t/p"

    /// TMDB profile images come in w45 / w185 / h632 / original.
    private let defaultProfileSize = "h632"
    /// TMDB poster images come in w92 / w154 / w185 / w342 / w500 / w780 / original.
    private let defaultPosterSize = "w780"

    private let session: URLSession

    // In-memory cache for responses
    private var cache: [String: (data: Any, timestamp: Date)] = [:]
    private let cacheTimeout: TimeInterval = 3600 // 1 hour cache
    private let maxCacheSize = 50

    /// TMDB serves snake_case; this maps it onto the camelCase DTOs in TMDBModels.swift.
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    init() {
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
        case missingAPIKey
        case apiError(String)
        case decodingError(Error)
        case networkError(Error)
        case httpError(Int)
        case actorNotFound

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid TMDB API URL"
            case .noData:
                return "No data received from TMDB"
            case .invalidIMDbID:
                return "Invalid or missing title ID"
            case .missingAPIKey:
                return "No TMDB access token configured. Add your token to Secrets.xcconfig."
            case .apiError(let message):
                return "TMDB API error: \(message)"
            case .decodingError(let error):
                return "Failed to decode TMDB data: \(error.localizedDescription)"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .httpError(let code):
                return code == 401
                    ? "TMDB rejected the access token (401). Check Secrets.xcconfig."
                    : "HTTP error: \(code)"
            case .actorNotFound:
                return "Actor not found in the TMDB database"
            }
        }
    }

    // MARK: - Configuration

    /// The TMDB read-only access token, injected at build time. `nil` when unset or
    /// still holding the placeholder from `Secrets.example.xcconfig`.
    private var readToken: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "TMDB_READ_TOKEN") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "your_tmdb_read_access_token_here" else {
            return nil
        }
        return trimmed
    }

    /// Whether metadata enrichment is available. Views can use this to hide
    /// IMDb-powered sections instead of surfacing an error.
    var isConfigured: Bool { readToken != nil }

    // MARK: - Public Methods

    /// Search for a person by name. When a movie's IMDb ID is supplied, the search is
    /// scoped to that film's billed cast, which disambiguates common names.
    func searchPerson(name: String, imdbMovieID: String? = nil) async throws -> IMDbPersonSearchResponse {
        print("🔍 TMDB: Searching for person '\(name)'")

        // Preferred path: match within the current film's cast.
        if let movieID = imdbMovieID {
            print("🎬 Using movie context: \(movieID)")
            if let actor = try? await findActorInMovie(actorName: name, imdbMovieID: movieID) {
                return IMDbPersonSearchResponse(results: [actor])
            }
            print("↩️ No cast match; falling back to global person search")
        }

        // Fallback: TMDB has a working person search (the old provider did not).
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw IMDbError.actorNotFound
        }

        let response: TMDBPersonSearchResponse = try await fetch(
            path: "/search/person",
            query: "query=\(encoded)&include_adult=false"
        )

        guard !response.results.isEmpty else {
            throw IMDbError.actorNotFound
        }

        return IMDbPersonSearchResponse(results: response.results.map { self.convertPersonSummary($0) })
    }

    /// Get detailed information about a person by TMDB person ID (or an `nm…` IMDb ID).
    func getPersonDetails(nameID: String) async throws -> IMDbPersonDetails {
        print("🔍 TMDB: Getting person details for '\(nameID)'")

        let cacheKey = "person_\(nameID)"
        if let cached = cache[cacheKey] as? (data: IMDbPersonDetails, timestamp: Date) {
            if Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
                print("🗄️ Using cached person details for \(nameID)")
                return cached.data
            }
        }

        let personID = try await resolvePersonID(nameID)
        let details: TMDBPersonDetails = try await fetch(path: "/person/\(personID)")

        let converted = IMDbPersonDetails(
            id: String(details.id),
            name: details.name,
            alternativeNames: details.alsoKnownAs,
            biography: details.biography,
            birthday: details.birthday,
            deathday: details.deathday,
            placeOfBirth: details.placeOfBirth,
            profilePath: profileURLString(details.profilePath),
            knownForDepartment: details.knownForDepartment,
            popularity: details.popularity ?? 0.0,
            heightCm: nil,      // TMDB does not expose height
            birthName: nil,     // TMDB does not expose birth name
            meterRanking: nil   // TMDB has no STARmeter equivalent; popularity is used instead
        )

        cache[cacheKey] = (data: converted, timestamp: Date())
        cleanupCache()

        return converted
    }

    /// Get a person's film credits, split into acting roles and crew roles.
    func getPersonMovieCredits(nameID: String) async throws -> IMDbPersonMovieCredits {
        print("🔍 TMDB: Getting movie credits for '\(nameID)'")

        let cacheKey = "credits_\(nameID)"
        if let cached = cache[cacheKey] as? (data: IMDbPersonMovieCredits, timestamp: Date) {
            if Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
                print("🗄️ Using cached movie credits for \(nameID)")
                return cached.data
            }
        }

        let personID = try await resolvePersonID(nameID)
        let response: TMDBPersonMovieCreditsResponse = try await fetch(path: "/person/\(personID)/movie_credits")

        let cast: [IMDbMovieCredit] = (response.cast ?? []).map { credit in
            IMDbMovieCredit(
                id: String(credit.id),
                title: credit.title ?? credit.originalTitle ?? "Unknown Title",
                character: credit.character,
                job: "Acting",
                releaseDate: credit.releaseDate,
                posterPath: posterURLString(credit.posterPath),
                voteAverage: credit.voteAverage ?? 0.0,
                popularity: credit.popularity ?? 0.0,
                episodeCount: nil
            )
        }

        let crew: [IMDbMovieCredit] = (response.crew ?? []).map { credit in
            IMDbMovieCredit(
                id: String(credit.id),
                title: credit.title ?? credit.originalTitle ?? "Unknown Title",
                character: nil,
                job: credit.job,
                releaseDate: credit.releaseDate,
                posterPath: posterURLString(credit.posterPath),
                voteAverage: credit.voteAverage ?? 0.0,
                popularity: credit.popularity ?? 0.0,
                episodeCount: nil
            )
        }

        print("✅ Converted to \(cast.count) cast credits and \(crew.count) crew credits")

        let converted = IMDbPersonMovieCredits(cast: cast, crew: crew)
        cache[cacheKey] = (data: converted, timestamp: Date())
        cleanupCache()

        return converted
    }

    /// Get gallery photos for a person.
    func getPersonImages(nameID: String) async throws -> [APIImage] {
        print("🔍 TMDB: Getting images for '\(nameID)'")

        let cacheKey = "images_\(nameID)"
        if let cached = cache[cacheKey] as? (data: [APIImage], timestamp: Date) {
            if Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
                print("🗄️ Using cached images for \(nameID)")
                return cached.data
            }
        }

        let personID = try await resolvePersonID(nameID)
        let response: TMDBPersonImagesResponse = try await fetch(path: "/person/\(personID)/images")

        let images: [APIImage] = (response.profiles ?? []).compactMap { profile in
            guard let url = profileURLString(profile.filePath) else { return nil }
            return APIImage(url: url, width: profile.width, height: profile.height)
        }

        cache[cacheKey] = (data: images, timestamp: Date())
        cleanupCache()

        return images
    }

    /// Get movie details by IMDb title ID (e.g. `tt0063350`).
    func getMovieDetails(imdbID: String) async throws -> IMDbMovieDetails {
        try await movieDetails(for: imdbID)
    }

    /// Get movie details by TMDB movie ID, or an IMDb `tt…` ID.
    func getMovieDetails(titleID: String) async throws -> IMDbMovieDetails {
        try await movieDetails(for: titleID)
    }

    /// Get top-billed cast for a film, by IMDb title ID.
    func getMovieCast(imdbID: String, limit: Int = 10) async throws -> [APICredit] {
        print("🎭 TMDB: Fetching movie cast for \(imdbID)")

        let cacheKey = "movieCast_\(imdbID)_\(limit)"
        if let cached = cache[cacheKey] as? (data: [APICredit], timestamp: Date) {
            if Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
                print("🗄️ Using cached cast for \(imdbID)")
                return cached.data
            }
        }

        let movieID = try await resolveMovieID(imdbID)
        let response: TMDBMovieCreditsResponse = try await fetch(path: "/movie/\(movieID)/credits")

        let ordered = (response.cast ?? []).sorted { ($0.order ?? Int.max) < ($1.order ?? Int.max) }
        let result: [APICredit] = ordered.prefix(limit).map { self.convertCastMember($0) }

        cache[cacheKey] = (data: result, timestamp: Date())
        cleanupCache()

        return result
    }

    /// Search for a movie by title.
    func searchMovie(title: String, year: Int? = nil) async throws -> IMDbMovieSearchResponse {
        print("🔍 TMDB: Searching for movie '\(title)'")

        guard let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw IMDbError.invalidURL
        }

        var query = "query=\(encoded)&include_adult=false"
        if let year = year {
            query += "&year=\(year)"
        }

        let response: TMDBMovieSearchResponse = try await fetch(path: "/search/movie", query: query)

        return IMDbMovieSearchResponse(results: response.results.map { movie in
            IMDbMovieSearchResult(
                id: String(movie.id),
                title: movie.title ?? movie.originalTitle ?? "Unknown Title",
                releaseDate: movie.releaseDate,
                overview: movie.overview,
                posterPath: posterURLString(movie.posterPath),
                voteAverage: movie.voteAverage ?? 0.0,
                popularity: movie.popularity ?? 0.0
            )
        })
    }

    /// Build a profile image URL. Accepts either an absolute URL (as stored in this
    /// service's domain models) or a bare TMDB path.
    func profileImageURL(path: String?, size: IMDbImageSize = .w500) -> URL? {
        imageURL(path: path, tmdbSize: size == .original ? "original" : defaultProfileSize)
    }

    /// Build a poster image URL. Accepts either an absolute URL or a bare TMDB path.
    func posterImageURL(path: String?, size: IMDbImageSize = .w342) -> URL? {
        imageURL(path: path, tmdbSize: size == .original ? "original" : size.rawValue)
    }

    // MARK: - Private: networking

    private func fetch<T: Decodable>(path: String, query: String? = nil) async throws -> T {
        guard let token = readToken else {
            print("❌ TMDB: no access token configured")
            throw IMDbError.missingAPIKey
        }

        var urlString = baseURL + path
        if let query = query, !query.isEmpty {
            urlString += "?" + query
        }

        guard let url = URL(string: urlString) else {
            throw IMDbError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Castarr/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                if let body = String(data: data, encoding: .utf8) {
                    print("❌ TMDB \(httpResponse.statusCode) for \(path): \(body.prefix(200))")
                }
                throw IMDbError.httpError(httpResponse.statusCode)
            }

            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                print("❌ TMDB decoding error for \(path): \(error)")
                if let body = String(data: data, encoding: .utf8) {
                    print("📄 Response (first 500 chars): \(body.prefix(500))")
                }
                throw IMDbError.decodingError(error)
            }
        } catch let error as IMDbError {
            throw error
        } catch {
            print("❌ TMDB network error for \(path): \(error)")
            throw IMDbError.networkError(error)
        }
    }

    // MARK: - Private: ID resolution

    /// Resolve an identifier to a TMDB movie ID. Accepts an IMDb `tt…` ID (resolved
    /// through `/find`) or an existing numeric TMDB ID (used as-is).
    private func resolveMovieID(_ identifier: String) async throws -> Int {
        if let numeric = Int(identifier) {
            return numeric
        }

        guard identifier.hasPrefix("tt") else {
            throw IMDbError.invalidIMDbID
        }

        let cacheKey = "findMovie_\(identifier)"
        if let cached = cache[cacheKey] as? (data: Int, timestamp: Date) {
            if Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
                return cached.data
            }
        }

        let response: TMDBFindResponse = try await fetch(
            path: "/find/\(identifier)",
            query: "external_source=imdb_id"
        )

        guard let match = response.movieResults?.first ?? response.tvResults?.first else {
            print("❌ TMDB: no title found for IMDb ID \(identifier)")
            throw IMDbError.invalidIMDbID
        }

        cache[cacheKey] = (data: match.id, timestamp: Date())
        cleanupCache()

        return match.id
    }

    /// Resolve an identifier to a TMDB person ID. Accepts a numeric TMDB ID or an
    /// IMDb `nm…` ID (resolved through `/find`).
    private func resolvePersonID(_ identifier: String) async throws -> Int {
        if let numeric = Int(identifier) {
            return numeric
        }

        guard identifier.hasPrefix("nm") else {
            throw IMDbError.actorNotFound
        }

        let cacheKey = "findPerson_\(identifier)"
        if let cached = cache[cacheKey] as? (data: Int, timestamp: Date) {
            if Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
                return cached.data
            }
        }

        let response: TMDBFindResponse = try await fetch(
            path: "/find/\(identifier)",
            query: "external_source=imdb_id"
        )

        guard let match = response.personResults?.first else {
            print("❌ TMDB: no person found for IMDb ID \(identifier)")
            throw IMDbError.actorNotFound
        }

        cache[cacheKey] = (data: match.id, timestamp: Date())
        cleanupCache()

        return match.id
    }

    // MARK: - Private: lookups

    private func movieDetails(for identifier: String) async throws -> IMDbMovieDetails {
        print("🎞️ TMDB: Fetching movie details for \(identifier)")

        let cacheKey = "movie_\(identifier)"
        if let cached = cache[cacheKey] as? (data: IMDbMovieDetails, timestamp: Date) {
            if Date().timeIntervalSince(cached.timestamp) < cacheTimeout {
                print("🗄️ Using cached movie details for \(identifier)")
                return cached.data
            }
        }

        let movieID = try await resolveMovieID(identifier)
        let details: TMDBMovieDetails = try await fetch(path: "/movie/\(movieID)")

        let converted = IMDbMovieDetails(
            id: String(details.id),
            title: details.title ?? details.originalTitle ?? "Unknown Title",
            originalTitle: details.originalTitle,
            releaseDate: details.releaseDate,
            runtime: details.runtime,
            overview: details.overview,
            tagline: (details.tagline?.isEmpty == false) ? details.tagline : nil,
            posterPath: posterURLString(details.posterPath),
            backdropPath: posterURLString(details.backdropPath),
            voteAverage: details.voteAverage ?? 0.0,
            voteCount: details.voteCount ?? 0,
            popularity: details.popularity ?? 0.0,
            genres: details.genres?.map { IMDbGenre(id: $0.id, name: $0.name) },
            productionCountries: details.productionCountries?.compactMap { country in
                guard let name = country.name else { return nil }
                return IMDbProductionCountry(iso31661: country.iso31661 ?? "", name: name)
            },
            spokenLanguages: details.spokenLanguages?.compactMap { language in
                guard let name = language.name else { return nil }
                return IMDbSpokenLanguage(iso6391: language.iso6391 ?? "", name: name)
            },
            productionCompanies: details.productionCompanies?.map { company in
                IMDbProductionCompany(
                    id: company.id,
                    name: company.name,
                    logoPath: posterURLString(company.logoPath),
                    originCountry: company.originCountry ?? ""
                )
            },
            budget: details.budget,
            revenue: details.revenue,
            status: details.status,
            adult: details.adult ?? false
        )

        cache[cacheKey] = (data: converted, timestamp: Date())
        cleanupCache()

        return converted
    }

    /// Find an actor by name within a specific film's billed cast.
    private func findActorInMovie(actorName: String, imdbMovieID: String) async throws -> IMDbPersonSearchResult? {
        print("🔍 Fetching credits for movie: \(imdbMovieID)")

        let movieID = try await resolveMovieID(imdbMovieID)
        let response: TMDBMovieCreditsResponse = try await fetch(path: "/movie/\(movieID)/credits")
        let cast = response.cast ?? []

        print("✅ Found \(cast.count) cast members")

        let target = actorName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let match = cast.first { member in
            let candidate = member.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            return candidate == target
                || candidate.contains(target)
                || target.contains(candidate)
        }

        guard let match = match else {
            print("❌ No matching actor found for '\(actorName)' in \(imdbMovieID)")
            return nil
        }

        print("✅ Found actor: \(match.name) (TMDB ID: \(match.id))")

        return IMDbPersonSearchResult(
            id: String(match.id),
            name: match.name,
            profilePath: profileURLString(match.profilePath),
            knownForDepartment: match.knownForDepartment ?? "Acting",
            popularity: 0.0,
            knownFor: []
        )
    }

    // MARK: - Private: conversion helpers

    private func convertPersonSummary(_ person: TMDBPersonSummary) -> IMDbPersonSearchResult {
        IMDbPersonSearchResult(
            id: String(person.id),
            name: person.name,
            profilePath: profileURLString(person.profilePath),
            knownForDepartment: person.knownForDepartment ?? "Acting",
            popularity: person.popularity ?? 0.0,
            knownFor: []
        )
    }

    private func convertCastMember(_ member: TMDBMovieCastMember) -> APICredit {
        let name = APIName(
            id: String(member.id),
            displayName: member.name,
            alternativeNames: nil,
            primaryImage: profileURLString(member.profilePath).map {
                APIImage(url: $0, width: nil, height: nil)
            },
            primaryProfessions: member.knownForDepartment.map { [$0] },
            biography: nil,
            heightCm: nil,
            birthName: nil,
            birthDate: nil,
            birthLocation: nil,
            deathDate: nil,
            deathLocation: nil,
            deathReason: nil,
            meterRanking: nil
        )

        return APICredit(
            title: nil,
            name: name,
            category: "ACTOR",
            characters: member.character.map { [$0] },
            episodeCount: nil
        )
    }

    // MARK: - Private: image URLs

    /// Absolute URL string for a TMDB profile path, at the default profile size.
    private func profileURLString(_ path: String?) -> String? {
        absoluteImageURLString(path, size: defaultProfileSize)
    }

    /// Absolute URL string for a TMDB poster/backdrop path, at the default poster size.
    private func posterURLString(_ path: String?) -> String? {
        absoluteImageURLString(path, size: defaultPosterSize)
    }

    private func absoluteImageURLString(_ path: String?, size: String) -> String? {
        guard let path = path, !path.isEmpty else { return nil }
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return path
        }
        let normalized = path.hasPrefix("/") ? path : "/" + path
        return "\(imageBaseURL)/\(size)\(normalized)"
    }

    private func imageURL(path: String?, tmdbSize: String) -> URL? {
        guard let string = absoluteImageURLString(path, size: tmdbSize) else { return nil }
        return URL(string: string)
    }

    // MARK: - Private: cache

    private func cleanupCache() {
        if cache.count > maxCacheSize {
            let sortedEntries = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            cache = Dictionary(uniqueKeysWithValues: Array(sortedEntries.suffix(maxCacheSize)))
        }
    }
}

// MARK: - Image Sizes
enum IMDbImageSize: String {
    case w92 = "w92"
    case w154 = "w154"
    case w185 = "w185"
    case w342 = "w342"
    case w500 = "w500"
    case w780 = "w780"
    case original = "original"
}
