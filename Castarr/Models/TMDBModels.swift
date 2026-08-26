//
//  TMDBModels.swift
//  Castarr
//
//  Wire-format models for The Movie Database (TMDB) REST API.
//
//  These are decoded with `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase`,
//  so TMDB's snake_case keys (profile_path, known_for_department, iso_3166_1, …)
//  map onto these camelCase properties automatically — no CodingKeys needed.
//
//  These types are the transport layer only. `IMDbService` converts them into the
//  app's domain models (IMDbPersonDetails, IMDbMovieCredit, …) so that the views
//  never see a TMDB-shaped type.
//

import Foundation

// MARK: - Shared

struct TMDBImage: Codable {
    let filePath: String?
    let width: Int?
    let height: Int?
    let voteAverage: Double?
}

struct TMDBGenre: Codable {
    let id: Int
    let name: String
}

struct TMDBProductionCountry: Codable {
    let iso31661: String?
    let name: String?
}

struct TMDBSpokenLanguage: Codable {
    let iso6391: String?
    let name: String?
}

struct TMDBProductionCompany: Codable {
    let id: Int
    let name: String
    let logoPath: String?
    let originCountry: String?
}

// MARK: - Find (external ID → TMDB)

/// Response from `/find/{imdb_id}?external_source=imdb_id`.
/// This is how Castarr bridges the IMDb IDs that Plex reports into TMDB IDs.
struct TMDBFindResponse: Codable {
    let movieResults: [TMDBMovieSummary]?
    let personResults: [TMDBPersonSummary]?
    let tvResults: [TMDBMovieSummary]?
}

// MARK: - Movies

struct TMDBMovieSummary: Codable {
    let id: Int
    let title: String?
    let originalTitle: String?
    let overview: String?
    let releaseDate: String?
    let posterPath: String?
    let voteAverage: Double?
    let popularity: Double?
}

struct TMDBMovieDetails: Codable {
    let id: Int
    let title: String?
    let originalTitle: String?
    let overview: String?
    let tagline: String?
    let releaseDate: String?
    let runtime: Int?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let popularity: Double?
    let genres: [TMDBGenre]?
    let productionCountries: [TMDBProductionCountry]?
    let spokenLanguages: [TMDBSpokenLanguage]?
    let productionCompanies: [TMDBProductionCompany]?
    let budget: Int?
    let revenue: Int?
    let status: String?
    let adult: Bool?
}

struct TMDBMovieSearchResponse: Codable {
    let results: [TMDBMovieSummary]
}

// MARK: - Movie credits (a film's cast list)

struct TMDBMovieCreditsResponse: Codable {
    let id: Int?
    let cast: [TMDBMovieCastMember]?
    let crew: [TMDBMovieCrewMember]?
}

struct TMDBMovieCastMember: Codable {
    let id: Int
    let name: String
    let character: String?
    let profilePath: String?
    let order: Int?
    let knownForDepartment: String?
}

struct TMDBMovieCrewMember: Codable {
    let id: Int
    let name: String
    let job: String?
    let department: String?
    let profilePath: String?
}

// MARK: - People

struct TMDBPersonSummary: Codable {
    let id: Int
    let name: String
    let profilePath: String?
    let knownForDepartment: String?
    let popularity: Double?
}

struct TMDBPersonSearchResponse: Codable {
    let results: [TMDBPersonSummary]
}

struct TMDBPersonDetails: Codable {
    let id: Int
    let name: String
    let alsoKnownAs: [String]?
    let biography: String?
    let birthday: String?
    let deathday: String?
    let placeOfBirth: String?
    let profilePath: String?
    let knownForDepartment: String?
    let popularity: Double?
}

struct TMDBPersonImagesResponse: Codable {
    let profiles: [TMDBImage]?
}

// MARK: - Person credits (a person's filmography)

struct TMDBPersonMovieCreditsResponse: Codable {
    let cast: [TMDBPersonCastCredit]?
    let crew: [TMDBPersonCrewCredit]?
}

struct TMDBPersonCastCredit: Codable {
    let id: Int
    let title: String?
    let originalTitle: String?
    let character: String?
    let releaseDate: String?
    let posterPath: String?
    let voteAverage: Double?
    let popularity: Double?
}

struct TMDBPersonCrewCredit: Codable {
    let id: Int
    let title: String?
    let originalTitle: String?
    let job: String?
    let releaseDate: String?
    let posterPath: String?
    let voteAverage: Double?
    let popularity: Double?
}
