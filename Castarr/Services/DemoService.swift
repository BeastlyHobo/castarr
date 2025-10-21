//
//  DemoService.swift
//  RoleCall
//
//  Created for demo mode functionality
//

import Foundation

@MainActor
class DemoService {
    static let shared = DemoService()
    static let demoEmail = "rolecalldemo@yahoo.com"
    
    private init() {}
    
    func isDemoUser(email: String) -> Bool {
        return email.lowercased() == Self.demoEmail.lowercased()
    }
    
    func createMockSessionsResponse() -> PlexSessionsResponse {
        let mockUser = SessionUser(
            id: 1,
            title: "Demo User",
            thumb: nil
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
            title: "It's A Wonderful Life",
            year: 1946,
            duration: 7800000,
            viewOffset: 3600000,
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
    
    func createMockMovieMetadata() -> PlexMovieMetadataResponse {
        let mockRoles = [
            MovieRole(id: "nm0000071", tag: "James Stewart", role: "George Bailey", thumb: "https://m.media-amazon.com/images/M/MV5BMjIwNzMzODY0NV5BMl5BanBnXkFtZTcwMDk3NDQyOA@@._V1_.jpg"),
            MovieRole(id: "nm0715070", tag: "Donna Reed", role: "Mary Hatch Bailey", thumb: "https://m.media-amazon.com/images/M/MV5BMmE5MTNiYTktZWZhMy00MWNmLTlkYTQtNGI5ODRkNzk4ZGQxXkEyXkFqcGc@._V1_.jpg"),
            MovieRole(id: "nm0000859", tag: "Lionel Barrymore", role: "Mr. Potter", thumb: "https://m.media-amazon.com/images/M/MV5BNzg0NmNlZGItYjQ0ZC00YjEyLThiZGQtNTFhM2MyMmMwODE1XkEyXkFqcGc@._V1_.jpg"),
            MovieRole(id: "nm0593775", tag: "Thomas Mitchell", role: "Uncle Billy", thumb: "https://m.media-amazon.com/images/M/MV5BOTcwNjAwMDI2M15BMl5BanBnXkFtZTcwNDMyNTUwOA@@._V1_.jpg"),
            MovieRole(id: "nm0871287", tag: "Henry Travers", role: "Clarence", thumb: "https://m.media-amazon.com/images/M/MV5BMTAxOTA4ODA1MTdeQTJeQWpwZ15BbWU3MDY1MTAwMjg@._V1_.jpg"),
            MovieRole(id: "nm0093462", tag: "Beulah Bondi", role: "Ma Bailey", thumb: "https://m.media-amazon.com/images/M/MV5BMjAyODAzNTIyOF5BMl5BanBnXkFtZTcwMzEwNjk5Nw@@._V1_.jpg"),
            MovieRole(id: "nm0269709", tag: "Frank Faylen", role: "Ernie Bishop", thumb: "https://m.media-amazon.com/images/M/MV5BOWY1MjhkMGQtODQ0Yi00ZTU4LTlkZmYtYWU3MWU2MjBiNzc5XkEyXkFqcGc@._V1_.jpg"),
            MovieRole(id: "nm0000955", tag: "Ward Bond", role: "Bert the Cop", thumb: "https://m.media-amazon.com/images/M/MV5BMTQxNDA1Nzk5OF5BMl5BanBnXkFtZTcwMzE2NDQyOA@@._V1_.jpg"),
            MovieRole(id: "nm0340102", tag: "Gloria Grahame", role: "Violet Bick", thumb: "https://m.media-amazon.com/images/M/MV5BYjFhNmU5ZWQtNDllMi00OGMxLWI0Y2EtMGE5ZjNjNTc5ZmY2XkEyXkFqcGc@._V1_.jpg"),
            MovieRole(id: "nm0912478", tag: "H.B. Warner", role: "Mr. Gower", thumb: "https://m.media-amazon.com/images/M/MV5BMTM1Mjc2NjgwMl5BMl5BanBnXkFtZTcwNTM4NDYwOA@@._V1_.jpg")
        ]
        
        let mockGenres = [
            MovieGenre(id: "1", tag: "Drama"),
            MovieGenre(id: "2", tag: "Family"),
            MovieGenre(id: "3", tag: "Fantasy")
        ]
        
        let mockCountries = [
            MovieCountry(id: "1", tag: "United States of America")
        ]
        
        let mockRatings = [
            MovieRating(
                id: "imdb",
                image: "imdb://image.rating",
                type: "audience",
                value: 8.6,
                count: 500000
            ),
            MovieRating(
                id: "tmdb",
                image: "themoviedb://image.rating",
                type: "audience",
                value: 8.4,
                count: 12000
            )
        ]
        
        let mockGuids = [
            MovieGuid(id: "imdb://tt0038650"),
            MovieGuid(id: "tmdb://1585"),
            MovieGuid(id: "tvdb://76169")
        ]
        
        let mockMovie = MovieMetadata(
            id: "12345",
            title: "It's A Wonderful Life",
            year: 1946,
            studio: "Liberty Films",
            summary: "George Bailey has spent his entire life giving of himself to the people of Bedford Falls. He has always longed to travel but never had the opportunity in order to prevent rich skinflint Mr. Potter from taking over the entire town. All that prevents him from doing so is George's modest building and loan company, which was founded by his generous father. On Christmas Eve 1945, George is about to jump from a bridge when into the icy water below when he is rescued by Clarence Odbody, a gentle angel who has yet to earn his wings. Clarence then shows George what things would have been like if he had never been born.",
            rating: 8.6,
            audienceRating: 8.4,
            audienceRatingImage: "rottentomatoes://image.rating.upright",
            contentRating: "PG",
            duration: 7800000,
            tagline: "It's a wonderful laugh! It's a wonderful love!",
            thumb: "https://m.media-amazon.com/images/M/MV5BMDM4OWFhYjEtNTE5Yy00NjcyLTg5N2UtZDQwNDZlYjlmNDU5XkEyXkFqcGc@._V1_.jpg",
            art: "https://m.media-amazon.com/images/M/MV5BMDM4OWFhYjEtNTE5Yy00NjcyLTg5N2UtZDQwNDZlYjlmNDU5XkEyXkFqcGc@._V1_.jpg",
            originallyAvailableAt: "1946-12-20",
            guid: "imdb://tt0038650",
            roles: mockRoles,
            directors: [MovieDirector(id: "nm0001008", tag: "Frank Capra", thumb: "https://m.media-amazon.com/images/M/MV5BNGNjYTM0MmMtYmMwZC00NWRjLWE3MDAtNDEyYWY3NWIzZTM1XkEyXkFqcGc@._V1_.jpg")],
            writers: [
                MovieWriter(id: "nm0329304", tag: "Frances Goodrich", thumb: nil),
                MovieWriter(id: "nm0352443", tag: "Albert Hackett", thumb: "https://m.media-amazon.com/images/M/MV5BZjk1NjM1NGEtYmVmNi00YjBhLTg0NWItOGVlNmI2ZDQzOTA4XkEyXkFqcGc@._V1_.jpg"),
                MovieWriter(id: "nm0001008", tag: "Frank Capra", thumb: "https://m.media-amazon.com/images/M/MV5BNGNjYTM0MmMtYmMwZC00NWRjLWE3MDAtNDEyYWY3NWIzZTM1XkEyXkFqcGc@._V1_.jpg")
            ],
            genres: mockGenres,
            countries: mockCountries,
            ratings: mockRatings,
            guids: mockGuids,
            ultraBlurColors: UltraBlurColors(
                bottomLeft: "#1a1a1a",
                bottomRight: "#2a2a2a",
                topLeft: "#3a3a3a",
                topRight: "#4a4a4a"
            )
        )
        
        let container = PlexMovieMetadataResponse.MovieMetadataContainer(
            size: 1,
            video: [mockMovie]
        )
        
        return PlexMovieMetadataResponse(mediaContainer: container)
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
