//
//  DemoService.swift
//  Castarr
//
//  Created for demo mode functionality
//

import Foundation

@MainActor
class DemoService {
    static let shared = DemoService()
    static let demoEmail = "castarrdemo@yahoo.com"
    private let imdbService = IMDbService()
    private let demoIMDbID = "tt0063350"
    
    private init() {}
    
    func isDemoUser(email: String) -> Bool {
        return email.lowercased() == Self.demoEmail.lowercased()
    }
    
    func createMockSessionsResponse() -> PlexSessionsResponse {
        let mockUser = SessionUser(
            id: 1,
            title: "Demo User",
            thumb: nil,
            uuid: "demo-user-uuid",
            email: Self.demoEmail
        )
        
        let mockPlayer = SessionPlayer(
            address: "192.168.1.100",
            device: "Apple TV",
            platform: "tvOS",
            product: "Plex for Apple TV",
            state: "playing",
            title: "Living Room",
            version: "8.0"
        )
        
        let mockTranscodeSession = TranscodeSession(
            key: "/transcode/sessions/mock123",
            progress: 45.5,
            speed: 1.2,
            duration: 7800000,
            videoDecision: "transcode",
            audioDecision: "directplay",
            container: "mkv",
            videoCodec: "h264",
            audioCodec: "aac"
        )
        
        let mockVideoSession = VideoSession(
            id: "12345",
            sessionKey: "mock-session-1",
            title: "Night of the Living Dead",
            year: 1968,
            duration: 5_760_000,
            viewOffset: 2_520_000,
            user: mockUser,
            player: mockPlayer,
            transcodeSession: mockTranscodeSession
        )
        
        let container = PlexSessionsResponse.SessionsContainer(
            size: 1,
            video: [mockVideoSession],
            track: nil
        )
        
        return PlexSessionsResponse(mediaContainer: container)
    }
    
    func createMockMovieMetadata() async -> PlexMovieMetadataResponse {
        let imdbDetails = try? await imdbService.getMovieDetails(imdbID: demoIMDbID)
        let imdbCast = (try? await imdbService.getMovieCast(imdbID: demoIMDbID, limit: 12)) ?? []

        let movieTitle = imdbDetails?.title ?? "Night of the Living Dead"
        let summary = imdbDetails?.overview ?? defaultSummary
        let releaseDate = imdbDetails?.releaseDate ?? "1968-10-01"
        let releaseYear = extractYear(from: releaseDate) ?? 1968
        let runtimeMinutes = imdbDetails?.runtime ?? 96
        let posterURL = imdbDetails?.posterPath ?? defaultPosterURL
        let artURL = imdbDetails?.posterPath ?? defaultPosterURL

        let roles = convertCreditsToMovieRoles(imdbCast)
        let genres = convertGenres(from: imdbDetails)
        let countries = convertCountries(from: imdbDetails)

        let mockRatings = [
            MovieRating(
                id: "imdb",
                image: "imdb://image.rating",
                type: "audience",
                value: 7.8,
                count: 320000
            ),
            MovieRating(
                id: "tmdb",
                image: "themoviedb://image.rating",
                type: "audience",
                value: 7.6,
                count: 11000
            )
        ]
        
        let mockGuids = [
            MovieGuid(id: "imdb://tt0063350"),
            MovieGuid(id: "tmdb://10331"),
            MovieGuid(id: "tvdb://191")
        ]
        
        let mockTechnical = MovieTechnicalInfo(
            videoResolution: "1080",
            videoCodec: "H.264",
            videoFrameRate: "24.000",
            aspectRatio: "1.37",
            audioCodec: "AAC",
            audioChannels: 2,
            audioProfile: "lc",
            container: "mp4",
            bitrate: 6_500_000,
            fileSize: 2_050_000_000
        )
        
        let mockMovie = MovieMetadata(
            id: "12345",
            title: movieTitle,
            year: releaseYear,
            studio: imdbDetails?.productionCompanies?.first?.name ?? "Image Ten",
            summary: summary,
            rating: imdbDetails?.voteAverage ?? 7.8,
            audienceRating: imdbDetails?.voteAverage ?? 7.6,
            audienceRatingImage: "rottentomatoes://image.rating.upright",
            contentRating: "NR",
            duration: runtimeMinutes * 60 * 1000,
            tagline: imdbDetails?.tagline ?? "They won't stay dead.",
            thumb: posterURL,
            art: artURL,
            originallyAvailableAt: releaseDate,
            guid: "imdb://\(demoIMDbID)",
            roles: roles.isEmpty ? defaultRoles : roles,
            directors: defaultDirectors,
            writers: defaultWriters,
            genres: genres,
            countries: countries,
            ratings: mockRatings,
            guids: mockGuids,
            ultraBlurColors: UltraBlurColors(
                bottomLeft: "#070809",
                bottomRight: "#1a1d1f",
                topLeft: "#2b3034",
                topRight: "#3e464b"
            ),
            technical: mockTechnical
        )
        
        let container = PlexMovieMetadataResponse.MovieMetadataContainer(
            size: 1,
            video: [mockMovie]
        )
        
        return PlexMovieMetadataResponse(mediaContainer: container)
    }

    // MARK: - Helpers
    private var defaultSummary: String {
        "When reports spread of the recently dead rising in rural Pennsylvania, strangers seek shelter inside a farmhouse. As the night wears on, the survivors fight off the encroaching ghouls while grappling with their own fear, mistrust, and dwindling options."
    }

    private var defaultPosterURL: String {
        placeholderImageURL(width: 720, height: 1080, text: "Night of the Living Dead")
    }

    private var defaultRoles: [MovieRole] {
        [
            MovieRole(id: "nm0429012", tag: "Duane Jones", role: "Ben", thumb: placeholderImageURL(text: "Duane Jones")),
            MovieRole(id: "nm0640861", tag: "Judith O'Dea", role: "Barbra", thumb: placeholderImageURL(text: "Judith O'Dea")),
            MovieRole(id: "nm0362208", tag: "Karl Hardman", role: "Harry Cooper", thumb: placeholderImageURL(text: "Karl Hardman")),
            MovieRole(id: "nm0247504", tag: "Marilyn Eastman", role: "Helen Cooper", thumb: placeholderImageURL(text: "Marilyn Eastman")),
            MovieRole(id: "nm0907750", tag: "Keith Wayne", role: "Tom", thumb: placeholderImageURL(text: "Keith Wayne")),
            MovieRole(id: "nm0725998", tag: "Judith Ridley", role: "Judy", thumb: placeholderImageURL(text: "Judith Ridley")),
            MovieRole(id: "nm0775032", tag: "Kyra Schon", role: "Karen Cooper", thumb: placeholderImageURL(text: "Kyra Schon")),
            MovieRole(id: "nm0834359", tag: "Russell Streiner", role: "Johnny", thumb: placeholderImageURL(text: "Russell Streiner")),
            MovieRole(id: "nm0385719", tag: "Bill Hinzman", role: "Cemetery Zombie", thumb: placeholderImageURL(text: "Bill Hinzman")),
            MovieRole(id: "nm0185849", tag: "Charles Craig", role: "Newscaster", thumb: placeholderImageURL(text: "Charles Craig"))
        ]
    }

    private var defaultDirectors: [MovieDirector] {
        [
            MovieDirector(id: "nm0001681", tag: "George A. Romero", thumb: placeholderImageURL(text: "George A. Romero"))
        ]
    }

    private var defaultWriters: [MovieWriter] {
        [
            MovieWriter(id: "nm0750988", tag: "John A. Russo", thumb: placeholderImageURL(text: "John A. Russo")),
            MovieWriter(id: "nm0001681", tag: "George A. Romero", thumb: placeholderImageURL(text: "George A. Romero"))
        ]
    }

    private func extractYear(from releaseDate: String?) -> Int? {
        guard let releaseDate else { return nil }
        if releaseDate.count == 4, let year = Int(releaseDate) { return year }
        return Int(releaseDate.prefix(4))
    }

    private func convertCreditsToMovieRoles(_ credits: [APICredit]) -> [MovieRole] {
        credits.compactMap { credit in
            guard let name = credit.name else { return nil }
            let id = name.id
            let actorName = name.displayName
            let thumb = name.primaryImage?.url ?? placeholderImageURL(text: actorName)
            let character = credit.characters?.first
            return MovieRole(id: id, tag: actorName, role: character, thumb: thumb)
        }
    }

    private func convertGenres(from details: IMDbMovieDetails?) -> [MovieGenre] {
        let list = details?.genres?.map { $0.name } ?? ["Horror", "Thriller", "Science Fiction"]
        return list.enumerated().map { index, value in
            MovieGenre(id: "\(index + 1)", tag: value)
        }
    }

    private func convertCountries(from details: IMDbMovieDetails?) -> [MovieCountry] {
        let list = details?.productionCountries?.map { $0.name } ?? ["United States of America"]
        return list.enumerated().map { index, value in
            MovieCountry(id: "\(index + 1)", tag: value)
        }
    }

    private func placeholderImageURL(width: Int = 400, height: Int = 400, text: String) -> String {
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        return "https://placehold.co/\(width)x\(height)?text=\(encoded)"
    }
    
    func createMockServerCapabilities() -> PlexCapabilitiesResponse {
        let container = PlexCapabilitiesResponse.MediaContainer(
            size: 0,
            allowCameraUpload: true,
            allowChannelAccess: true,
            allowMediaDeletion: false,
            allowSharing: true,
            allowSync: true,
            allowTuners: false,
            backgroundProcessing: true,
            certificate: true,
            companionProxy: true,
            friendlyName: "Demo Plex Server",
            version: "1.32.5.7349",
            platform: "Linux",
            platformVersion: "4.4.0",
            machineIdentifier: "demo-server-123",
            myPlex: true,
            myPlexUsername: "Demo User",
            myPlexSigninState: "ok",
            myPlexSubscription: true,
            multiuser: true,
            transcoderAudio: true,
            transcoderVideo: true,
            transcoderSubtitles: true,
            transcoderPhoto: true,
            transcoderActiveVideoSessions: 1,
            transcoderVideoResolutions: "1080p,720p,480p",
            transcoderVideoBitrates: "20000,10000,4000,2000",
            transcoderVideoQualities: "100,80,60,40",
            livetv: 0,
            photoAutoTag: true,
            voiceSearch: true,
            pushNotifications: true
        )
        
        return PlexCapabilitiesResponse(
            mediaContainer: container,
            product: "Plex Media Server",
            state: "running",
            title: "Demo Plex Server",
            version: "1.32.5.7349"
        )
    }
    
    func createMockActivitiesResponse() -> PlexActivitiesResponse {
        let container = PlexActivitiesResponse.ActivitiesContainer(
            size: 0,
            activity: nil
        )
        
        return PlexActivitiesResponse(mediaContainer: container)
    }
}
