//
//  PlexModels.swift
//  RoleCall
//
//  Created by Eric on 7/28/25.
//

import Foundation

// MARK: - Plex Settings Model
struct PlexSettings: Codable {
    var serverIP: String = ""
    var plexToken: String = ""
    var tokenExpirationDate: Date?
    var username: String = "" // Store username for convenience

    var isTokenValid: Bool {
        // Don't check artificial expiration dates - let the actual API calls determine validity
        return !plexToken.isEmpty
    }

    var hasValidLogin: Bool {
        return !serverIP.isEmpty && !plexToken.isEmpty && isTokenValid
    }
}

// MARK: - Plex Authentication Response
struct PlexAuthResponse: Codable {
    let user: PlexUser

    struct PlexUser: Codable {
        let id: Int
        let uuid: String
        let email: String
        let title: String
        let username: String
        let authToken: String

        private enum CodingKeys: String, CodingKey {
            case id, uuid, email, title, username
            case authToken = "authToken"
        }
    }
}

// MARK: - Plex OAuth PIN Response
struct PlexPinResponse: Codable {
    let id: Int
    let code: String
    let authToken: String?
    let expiresAt: String?
    let createdAt: String?
    let updatedAt: String?
    let trusted: Bool?
    let clientIdentifier: String?
    
    var isAuthenticated: Bool {
        return authToken != nil && !(authToken ?? "").isEmpty
    }
}

// MARK: - Plex Server Capabilities Response
struct PlexCapabilitiesResponse: Codable {
    let mediaContainer: MediaContainer
    let product: String?
    let state: String?
    let title: String?
    let version: String?

    private enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
        case product, state, title, version
    }

    struct MediaContainer: Codable {
        let size: Int?
        let allowCameraUpload: Bool?
        let allowChannelAccess: Bool?
        let allowMediaDeletion: Bool?
        let allowSharing: Bool?
        let allowSync: Bool?
        let allowTuners: Bool?
        let backgroundProcessing: Bool?
        let certificate: Bool?
        let companionProxy: Bool?
        let friendlyName: String?
        let version: String?
        let platform: String?
        let platformVersion: String?
        let machineIdentifier: String?
        let myPlex: Bool?
        let myPlexUsername: String?
        let myPlexSigninState: String?
        let myPlexSubscription: Bool?
        let multiuser: Bool?
        let transcoderAudio: Bool?
        let transcoderVideo: Bool?
        let transcoderSubtitles: Bool?
        let transcoderPhoto: Bool?
        let transcoderActiveVideoSessions: Int?
        let transcoderVideoResolutions: String?
        let transcoderVideoBitrates: String?
        let transcoderVideoQualities: String?
        let livetv: Int?
        let photoAutoTag: Bool?
        let voiceSearch: Bool?
        let pushNotifications: Bool?
    }
}

// MARK: - New IMDb API (imdbapi.dev) Models

// Search Titles Response
struct SearchTitlesResponse: Codable {
    let titles: [APITitle]
}

// Title model (used by search and detail)
struct APITitle: Codable {
    let id: String
    let type: String?
    let isAdult: Bool?
    let primaryTitle: String?
    let originalTitle: String?
    let primaryImage: APIImage?
    let startYear: Int?
    let endYear: Int?
    let runtimeSeconds: Int?
    let plot: String?
    let genres: [String]?
    let rating: APIRating?
}

struct APIRating: Codable {
    let aggregateRating: Double?
    let voteCount: Int?
}

struct APIImage: Codable {
    let url: String?
    let width: Int?
    let height: Int?
}

// Name (person) model
struct APIName: Codable {
    let id: String
    let displayName: String
    let alternativeNames: [String]?
    let primaryImage: APIImage?
    let primaryProfessions: [String]?
    let biography: String?
    let heightCm: Int?
    let birthName: String?
    let birthDate: APIPrecisionDate?
    let birthLocation: String?
    let deathDate: APIPrecisionDate?
    let deathLocation: String?
    let deathReason: String?
    let meterRanking: APIMeterRanking?
}

struct APIMeterRanking: Codable {
    let currentRank: Int?
    let changeDirection: String?
    let difference: Int?
}

struct APIPrecisionDate: Codable {
    let year: Int?
    let month: Int?
    let day: Int?
}

// Filmography and Credits
struct APIFilmographyResponse: Codable {
    let credits: [APICredit]
    let totalCount: Int?
    let nextPageToken: String?
}

struct APICreditsResponse: Codable {
    let credits: [APICredit]
}

struct APICredit: Codable {
    let title: APITitle?
    let name: APIName?
    let category: String?
    let characters: [String]?
    let episodeCount: Int?
}

// MARK: - IMDb Images Response
struct APIImagesResponse: Codable {
    let images: [APIImage]
    let totalCount: Int?
    let nextPageToken: String?
}

// MARK: - IMDb Relationships Response
struct APIRelationshipsResponse: Codable {
    let relationships: [APIRelationship]
}

struct APIRelationship: Codable {
    let relationType: String?
    let name: APIName
    let attributes: [String]?
}

// MARK: - IMDb Trivia Response
struct APITriviaResponse: Codable {
    let trivia: [APITriviaItem]
    let totalCount: Int?
    let nextPageToken: String?
}

struct APITriviaItem: Codable, Identifiable {
    let id: String
    let text: String
    let interestCount: Int?
    let voteCount: Int?
}

// MARK: - Plex Activities Response
struct PlexActivitiesResponse: Codable {
    let mediaContainer: ActivitiesContainer
    
    private enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }
    
    struct ActivitiesContainer: Codable {
        let size: Int
        let activity: [Activity]?
        
        private enum CodingKeys: String, CodingKey {
            case size
            case activity = "Activity"
        }
        
        struct Activity: Codable, Identifiable {
            let id: String
            let type: String?
            let cancellable: Int?
            let userID: Int?
            let title: String?
            let subtitle: String?
            let progress: Int?
            let context: [Context]?
            
            var isCancellable: Bool {
                return cancellable == 1
            }
            
            private enum CodingKeys: String, CodingKey {
                case id = "uuid"
                case type, cancellable, userID, title, subtitle, progress, context
            }
            
            struct Context: Codable {
                let librarySectionID: String?
            }
        }
    }
}

// MARK: - Plex Sessions Response
struct PlexSessionsResponse: Codable {
    let mediaContainer: SessionsContainer
    
    private enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }
    
    struct SessionsContainer: Codable {
        let size: Int
        let video: [VideoSession]?
        let track: [TrackSession]?
        
        private enum CodingKeys: String, CodingKey {
            case size
            case video = "Video"
            case track = "Track"
        }
    }
}

// MARK: - Video Session
struct VideoSession: Codable, Identifiable {
    let id: String
    let sessionKey: String?
    let title: String?
    let year: Int?
    let duration: Int?
    let viewOffset: Int?
    let user: SessionUser?
    let player: SessionPlayer?
    let transcodeSession: TranscodeSession?
    
    private enum CodingKeys: String, CodingKey {
        case id = "ratingKey"
        case sessionKey, title, year, duration, viewOffset, user, player, transcodeSession
    }
}

// MARK: - Track Session
struct TrackSession: Codable, Identifiable {
    let id: String
    let sessionKey: String?
    let title: String?
    let parentTitle: String?
    let grandparentTitle: String?
    let duration: Int?
    let viewOffset: Int?
    let user: SessionUser?
    let player: SessionPlayer?
    
    private enum CodingKeys: String, CodingKey {
        case id = "ratingKey"
        case sessionKey, title, parentTitle, grandparentTitle, duration, viewOffset, user, player
    }
}

// MARK: - Session User
struct SessionUser: Codable, Identifiable {
    let id: Int
    let title: String
    let thumb: String?
}

// MARK: - Session Player
struct SessionPlayer: Codable {
    let address: String?
    let device: String?
    let platform: String?
    let product: String?
    let state: String?
    let title: String?
    let version: String?
}

// MARK: - Transcode Session
struct TranscodeSession: Codable {
    let key: String?
    let progress: Double?
    let speed: Double?
    let duration: Int?
    let videoDecision: String?
    let audioDecision: String?
    let container: String?
    let videoCodec: String?
    let audioCodec: String?
}

// MARK: - Plex Movie Metadata Response
struct PlexMovieMetadataResponse: Codable {
    let mediaContainer: MovieMetadataContainer

    private enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }

    struct MovieMetadataContainer: Codable {
        let size: Int
        let video: [MovieMetadata]?

        private enum CodingKeys: String, CodingKey {
            case size
            case video = "Video"
        }
    }
}

// MARK: - Movie Metadata
struct MovieMetadata: Codable, Identifiable {
    let id: String
    let title: String?
    let year: Int?
    let studio: String?
    let summary: String?
    let rating: Double?
    let audienceRating: Double?
    let audienceRatingImage: String?
    let contentRating: String?
    let duration: Int?
    let tagline: String?
    let thumb: String?
    let art: String?
    let originallyAvailableAt: String?
    let guid: String? // External metadata provider ID

    // Cast and Crew
    let roles: [MovieRole]?
    let directors: [MovieDirector]?
    let writers: [MovieWriter]?
    let genres: [MovieGenre]?
    let countries: [MovieCountry]?
    let ratings: [MovieRating]?
    let guids: [MovieGuid]? // External IDs array
    let ultraBlurColors: UltraBlurColors?

    private enum CodingKeys: String, CodingKey {
        case id = "ratingKey"
        case title, year, studio, summary, rating, audienceRating, audienceRatingImage, contentRating, duration, tagline, thumb, art, originallyAvailableAt, guid
        case roles = "Role"
        case directors = "Director"
        case writers = "Writer"
        case genres = "Genre"
        case countries = "Country"
        case ratings = "Rating"
        case guids = "Guid"
        case ultraBlurColors = "UltraBlurColors"
    }
    
    // Extract IMDb ID from guid or guids array
    var imdbID: String? {
        // Check the main guid field first
        if let guid = guid {
            if let imdbID = extractIMDbID(from: guid) {
                return imdbID
            }
        }
        
        // Check the guids array for IMDb entries
        if let guids = guids {
            for guidEntry in guids {
                if let imdbID = extractIMDbID(from: guidEntry.id) {
                    return imdbID
                }
            }
        }
        
        return nil
    }
    
    private func extractIMDbID(from guid: String) -> String? {
        // Plex stores IMDb IDs in formats like:
        // "imdb://tt1234567"
        // "com.plexapp.agents.imdb://tt1234567?lang=en"
        
        if guid.contains("imdb://") {
            return guid.components(separatedBy: "imdb://").last?.components(separatedBy: "?").first
        } else if guid.contains("agents.imdb://") {
            return guid.components(separatedBy: "agents.imdb://").last?.components(separatedBy: "?").first
        }
        
        return nil
    }
}

// MARK: - Movie GUID (External IDs)
struct MovieGuid: Codable, Identifiable {
    let id: String // The external ID like "imdb://tt1234567"
    
    private enum CodingKeys: String, CodingKey {
        case id
    }
}

// MARK: - Movie Role (Cast)
struct MovieRole: Codable, Identifiable {
    let id: String
    let tag: String // Actor name
    let role: String? // Character name
    let thumb: String? // Actor photo

    private enum CodingKeys: String, CodingKey {
        case id
        case tag, role, thumb
    }
}

// MARK: - Movie Director
struct MovieDirector: Codable, Identifiable {
    let id: String
    let tag: String // Director name
    let thumb: String? // Director photo

    private enum CodingKeys: String, CodingKey {
        case id
        case tag, thumb
    }
}

// MARK: - Movie Writer
struct MovieWriter: Codable, Identifiable {
    let id: String
    let tag: String // Writer name
    let thumb: String? // Writer photo

    private enum CodingKeys: String, CodingKey {
        case id
        case tag, thumb
    }
}

// MARK: - Movie Genre
struct MovieGenre: Codable, Identifiable {
    let id: String
    let tag: String // Genre name

    private enum CodingKeys: String, CodingKey {
        case id
        case tag
    }
}

// MARK: - Movie Country
struct MovieCountry: Codable, Identifiable {
    let id: String
    let tag: String // Country name

    private enum CodingKeys: String, CodingKey {
        case id
        case tag
    }
}

// MARK: - Movie Rating
struct MovieRating: Codable, Identifiable {
    let id: String?
    let image: String?
    let type: String?
    let value: Double?
    let count: Int?

    // Generate a computed ID based on image and type since XML doesn't provide one
    var computedId: String {
        return "\(image ?? "unknown")_\(type ?? "unknown")"
    }

    // Manual initializer for XML parsing
    init(id: String?, image: String?, type: String?, value: Double?, count: Int?) {
        self.id = id
        self.image = image
        self.type = type
        self.value = value
        self.count = count
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        print("🔍 DEBUG: Decoding MovieRating...")

        // Try to decode as XML attributes first, then fall back to elements
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.image = try container.decodeIfPresent(String.self, forKey: .image)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)

        // Handle count which might be a string in XML
        if let countString = try container.decodeIfPresent(String.self, forKey: .count) {
            self.count = Int(countString)
        } else {
            self.count = try container.decodeIfPresent(Int.self, forKey: .count)
        }

        // Handle value which might be a string in XML
        if let valueString = try container.decodeIfPresent(String.self, forKey: .value) {
            self.value = Double(valueString)
        } else {
            self.value = try container.decodeIfPresent(Double.self, forKey: .value)
        }

        print("🔍 DEBUG: MovieRating decoded - image: \(self.image ?? "nil"), type: \(self.type ?? "nil"), value: \(self.value?.description ?? "nil"), count: \(self.count?.description ?? "nil")")
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case image, type, value, count
    }
}

// MARK: - Ultra Blur Colors
struct UltraBlurColors: Codable {
    let bottomLeft: String?
    let bottomRight: String?
    let topLeft: String?
    let topRight: String?
}

// MARK: - Plex Error Response
struct PlexErrorResponse: Codable {
    let errors: [PlexError]

    struct PlexError: Codable {
        let code: Int
        let message: String
        let status: Int
    }
}


// MARK: - IMDb Models

// IMDb Person Search Response
struct IMDbPersonSearchResponse: Codable {
    let results: [IMDbPersonSearchResult]
}

struct IMDbPersonSearchResult: Codable, Identifiable {
    let id: String // IMDb name ID (nm0000001 format)
    let name: String
    let profilePath: String?
    let knownForDepartment: String?
    let popularity: Double
    let knownFor: [IMDbKnownForMovie]?
}

struct IMDbKnownForMovie: Codable, Identifiable {
    let id: String // IMDb title ID (tt0000001 format)
    let title: String?
    let releaseDate: String?
    let posterPath: String?
    let mediaType: String

    var displayTitle: String {
        return title ?? "Unknown Title"
    }
}

// IMDb Person Details Response
struct IMDbPersonDetails: Codable, Identifiable {
    let id: String // IMDb name ID
    let name: String
    let alternativeNames: [String]?
    let biography: String?
    let birthday: String?
    let deathday: String?
    let placeOfBirth: String?
    let profilePath: String?
    let knownForDepartment: String?
    let popularity: Double
    let heightCm: Int?
    let birthName: String?
    let meterRanking: MeterRanking?
}

struct MeterRanking: Codable {
    let currentRank: Int?
    let changeDirection: String?
    let difference: Int?
    
    var isRising: Bool {
        return changeDirection?.uppercased() == "UP"
    }
    
    var isFalling: Bool {
        return changeDirection?.uppercased() == "DOWN"
    }
}

// IMDb Person Movie Credits Response
struct IMDbPersonMovieCredits: Codable {
    let cast: [IMDbMovieCredit]
    let crew: [IMDbMovieCredit]
}

struct IMDbMovieCredit: Codable, Identifiable {
    let id: String // IMDb title ID
    let title: String
    let character: String?
    let job: String?
    let releaseDate: String?
    let posterPath: String?
    let voteAverage: Double
    let popularity: Double
    let episodeCount: Int?
}

// IMDb Movie Search Response
struct IMDbMovieSearchResponse: Codable {
    let results: [IMDbMovieSearchResult]
}

struct IMDbMovieSearchResult: Codable, Identifiable {
    let id: String // IMDb title ID
    let title: String
    let releaseDate: String?
    let overview: String?
    let posterPath: String?
    let voteAverage: Double
    let popularity: Double
}

// IMDb Movie Details Response
struct IMDbMovieDetails: Codable, Identifiable {
    let id: String // IMDb title ID
    let title: String
    let originalTitle: String?
    let releaseDate: String?
    let runtime: Int? // in minutes
    let overview: String?
    let tagline: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double
    let voteCount: Int
    let popularity: Double
    let genres: [IMDbGenre]?
    let productionCountries: [IMDbProductionCountry]?
    let spokenLanguages: [IMDbSpokenLanguage]?
    let productionCompanies: [IMDbProductionCompany]?
    let budget: Int?
    let revenue: Int?
    let status: String? // Released, Post Production, etc.
    let adult: Bool
    
    var displayTitle: String {
        return title
    }
    
    var releaseYear: String? {
        guard let releaseDate = releaseDate else { return nil }
        return String(releaseDate.prefix(4))
    }
    
    var formattedRuntime: String? {
        guard let runtime = runtime else { return nil }
        let hours = runtime / 60
        let minutes = runtime % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct IMDbGenre: Codable, Identifiable {
    let id: Int
    let name: String
}

struct IMDbProductionCountry: Codable {
    let iso31661: String
    let name: String
    
    private enum CodingKeys: String, CodingKey {
        case iso31661 = "iso_3166_1"
        case name
    }
}

struct IMDbSpokenLanguage: Codable {
    let iso6391: String
    let name: String
    
    private enum CodingKeys: String, CodingKey {
        case iso6391 = "iso_639_1"
        case name
    }
}

struct IMDbProductionCompany: Codable, Identifiable {
    let id: Int
    let name: String
    let logoPath: String?
    let originCountry: String
    
    private enum CodingKeys: String, CodingKey {
        case id, name
        case logoPath = "logo_path"
        case originCountry = "origin_country"
    }
}

// MARK: - IMDb REST API Internal Models

struct TitleSearchResponse: Codable {
    let results: [TitleSearchResult]
}

struct IMDbTitleDetailResponse: Codable {
    let id: String
    let primaryTitle: String?
    let originalTitle: String?
    let startYear: Int?
    let runtimeMinutes: Int?
    let plot: String?
    let genres: [String]?
    let rating: IMDbRating?
    let primaryImage: IMDbImage?
    let isAdult: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, plot, genres, rating
        case primaryTitle = "primary_title"
        case originalTitle = "original_title"
        case startYear = "start_year"
        case runtimeMinutes = "runtime_minutes"
        case primaryImage = "primary_image"
        case isAdult = "is_adult"
    }
}

struct IMDbRating: Codable {
    let aggregateRating: Double?
    let numVotes: Int?
    
    enum CodingKeys: String, CodingKey {
        case aggregateRating = "aggregate_rating"
        case numVotes = "num_votes"
    }
}

struct IMDbImage: Codable {
    let url: String?
    let width: Int?
    let height: Int?
    
    enum CodingKeys: String, CodingKey {
        case url, width, height
    }
}

struct TitleSearchResult: Codable {
    let id: String
    let primaryTitle: String
    let startYear: Int?
    let plot: String?
    let genres: [String]?
    let rating: RestRating?
    let primaryImage: RestImage?

    enum CodingKeys: String, CodingKey {
        case id, plot, genres, rating
        case primaryTitle = "primary_title"
        case startYear = "start_year"
        case primaryImage = "primary_image"
    }
}

struct RestCreditsResponse: Codable {
    let credits: [RestCredit]
}

struct RestCredit: Codable {
    let name: RestName
    let category: String
    let characters: [String]?
}

struct RestName: Codable {
    let id: String
    let displayName: String
    let primaryImage: RestImage?
    let birthDate: RestBirthDate?
    let deathDate: RestBirthDate?
    let birthLocation: String?
    let deathLocation: String?
    let deathReason: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case primaryImage = "primary_image"
        case birthDate = "birth_date"
        case deathDate = "death_date"
        case birthLocation = "birth_location"
        case deathLocation = "death_location"
        case deathReason = "death_reason"
    }
}

struct RestPersonInfo: Codable {
    let id: String
    let displayName: String
    let primaryImage: RestImage?
    let biography: String?
    let birthDate: RestBirthDate?
    let birthLocation: String?
    let deathDate: RestBirthDate?
    let deathLocation: String?
    let deathReason: String?
    let primaryProfessions: [String]?

    enum CodingKeys: String, CodingKey {
        case id, biography
        case displayName = "display_name"
        case primaryImage = "primary_image"
        case birthDate = "birth_date"
        case birthLocation = "birth_location"
        case deathDate = "death_date"
        case deathLocation = "death_location"
        case deathReason = "death_reason"
        case primaryProfessions = "primary_professions"
    }
}

struct RestBirthDate: Codable {
    let year: Int?
    let month: Int?
    let day: Int?
}

struct RestKnownForResponse: Codable {
    let knownFor: [RestKnownForCredit]

    enum CodingKeys: String, CodingKey {
        case knownFor = "known_for"
    }
}

struct RestKnownForCredit: Codable {
    let title: RestKnownForTitle?
    let category: String?
    let characters: [String]?
}

struct RestKnownForTitle: Codable {
    let id: String
    let primaryTitle: String
    let startYear: Int?
    let genres: [String]?
    let rating: RestRating?
    let primaryImage: RestImage?
    let plot: String?

    enum CodingKeys: String, CodingKey {
        case id, genres, rating, plot
        case primaryTitle = "primary_title"
        case startYear = "start_year"
        case primaryImage = "primary_image"
    }
}

struct RestRating: Codable {
    let aggregateRating: Double
    let votesCount: Int

    enum CodingKeys: String, CodingKey {
        case aggregateRating = "aggregate_rating"
        case votesCount = "votes_count"
    }
}

struct RestImage: Codable {
    let url: String
    let width: Int
    let height: Int
}

// MARK: - Wyzie Subtitle Models
struct WyzieSubtitleResponse: Codable {
    let id: String
    let url: String
    let flagUrl: String
    let format: String
    let encoding: String
    let display: String
    let language: String
    let media: String
    let isHearingImpaired: Bool
    let source: String
}

