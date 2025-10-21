//
//  PlexService.swift
//  RoleCall
//
//  Created by Eric on 7/28/25.
//

import Foundation
import Combine
import UIKit

@MainActor
class PlexService: ObservableObject {
    @Published var settings = PlexSettings()
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var serverCapabilities: PlexCapabilitiesResponse?
    @Published var activities: PlexActivitiesResponse?
    @Published var sessions: PlexSessionsResponse?
    @Published var movieMetadata: PlexMovieMetadataResponse?
    @Published var selectedSessionIndex = 0
    @Published var isDemoMode = false

    private let userDefaults = UserDefaults.standard
    private let settingsKey = "PlexSettings"
    private let demoService = DemoService.shared
    private let clientIdentifier = UUID().uuidString

    // Track current sessions task to prevent conflicts
    private var currentSessionsTask: Task<Void, Never>?
    
    // OAuth polling task
    private var pollingTask: Task<Void, Never>?

    // Custom URLSession with better network configuration
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0 // 15 seconds for request timeout
        config.timeoutIntervalForResource = 30.0 // 30 seconds for resource timeout
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        // Prevent request caching to ensure fresh data
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        // Add better support for self-signed certificates (common with external Plex servers)
        return URLSession(configuration: config, delegate: PlexURLSessionDelegate(), delegateQueue: nil)
    }()

    init() {
        loadSettings()

        // Check for demo mode first
        if demoService.isDemoUser(email: settings.username) && !settings.plexToken.isEmpty {
            print("🎬 Demo mode detected on init")
            isDemoMode = true
            isLoggedIn = true
            return
        }
        
        // Check if we have saved credentials
        if settings.hasValidLogin {
            print("🔐 Found saved credentials for user: \(settings.username)")
            print("🏠 Server IP: \(settings.serverIP)")
            isLoggedIn = true
            checkTokenValidity()
        } else {
            print("ℹ️ No valid saved credentials found")
            isLoggedIn = false
        }
    }

    deinit {
        // Cancel any ongoing tasks when the service is deallocated
        currentSessionsTask?.cancel()
    }

    // MARK: - Settings Management
    func loadSettings() {
        if let data = userDefaults.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(PlexSettings.self, from: data) {
            self.settings = settings
        }
    }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
        }
    }

    func updateServerIP(_ ip: String) {
        settings.serverIP = ip
        saveSettings()
    }


    // MARK: - Authentication
    
    func startOAuthLogin() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let pinResponse = try await generatePIN()
            let authURL = constructAuthURL(pin: pinResponse.code)
            
            if let url = URL(string: authURL) {
                await UIApplication.shared.open(url)
            }
            
            try await pollForAuthentication(pinID: pinResponse.id)
        } catch {
            errorMessage = error.localizedDescription
            print("❌ OAuth login failed: \(error.localizedDescription)")
            isLoading = false
        }
    }
    
    func loginDemo(email: String) async {
        isLoading = true
        errorMessage = nil
        
        if demoService.isDemoUser(email: email) {
            print("🎬 Demo mode activated for user: \(email)")
            isDemoMode = true
            settings.plexToken = "demo-token-12345"
            settings.username = email
            settings.serverIP = "192.168.1.100"
            settings.tokenExpirationDate = nil
            saveSettings()
            isLoggedIn = true
            
            serverCapabilities = demoService.createMockServerCapabilities()
            sessions = demoService.createMockSessionsResponse()
            movieMetadata = demoService.createMockMovieMetadata()
            activities = demoService.createMockActivitiesResponse()
            
            print("✅ Demo mode login successful for user: \(email)")
        } else {
            errorMessage = "Invalid demo account credentials"
        }
        
        isLoading = false
    }
    
    private func generatePIN() async throws -> PlexPinResponse {
        guard let url = URL(string: "https://plex.tv/api/v2/pins") else {
            throw PlexError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("RoleCall", forHTTPHeaderField: "X-Plex-Product")
        request.setValue(clientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")
        
        let body = "strong=true"
        request.httpBody = body.data(using: .utf8)
        
        print("🔐 Generating PIN...")
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlexError.invalidResponse
        }
        
        print("📊 PIN Response status: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 201 else {
            throw PlexError.serverError(httpResponse.statusCode)
        }
        
        let pinResponse = try JSONDecoder().decode(PlexPinResponse.self, from: data)
        print("✅ PIN generated: \(pinResponse.id)")
        return pinResponse
    }
    
    private func constructAuthURL(pin: String) -> String {
        let baseURL = "https://app.plex.tv/auth#?"
        let params = [
            "clientID": clientIdentifier,
            "code": pin,
            "context[device][product]": "RoleCall"
        ]
        
        let queryString = params.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
        
        return baseURL + queryString
    }
    
    private func pollForAuthentication(pinID: Int) async throws {
        let maxAttempts = 300
        var attempts = 0
        
        pollingTask = Task {
            while attempts < maxAttempts && !Task.isCancelled {
                attempts += 1
                
                do {
                    let pinResponse = try await checkPINStatus(pinID: pinID)
                    
                    if pinResponse.isAuthenticated, let token = pinResponse.authToken {
                        print("✅ Authentication successful!")
                        await MainActor.run {
                            settings.plexToken = token
                            settings.username = ""
                            settings.tokenExpirationDate = nil
                            saveSettings()
                            isLoggedIn = true
                            isDemoMode = false
                            isLoading = false
                        }
                        return
                    }
                } catch {
                    print("⚠️ Error checking PIN status: \(error.localizedDescription)")
                }
                
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            
            if attempts >= maxAttempts {
                await MainActor.run {
                    errorMessage = "Authentication timeout. Please try again."
                    isLoading = false
                }
            }
        }
        
        await pollingTask?.value
    }
    
    private func checkPINStatus(pinID: Int) async throws -> PlexPinResponse {
        guard let url = URL(string: "https://plex.tv/api/v2/pins/\(pinID)") else {
            throw PlexError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(clientIdentifier, forHTTPHeaderField: "X-Plex-Client-Identifier")
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlexError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw PlexError.serverError(httpResponse.statusCode)
        }
        
        let pinResponse = try JSONDecoder().decode(PlexPinResponse.self, from: data)
        return pinResponse
    }

    func checkTokenValidity() {
        if isDemoMode {
            print("🎬 Demo mode: Skipping token validation")
            isLoggedIn = true
            return
        }
        
        guard !settings.serverIP.isEmpty, !settings.plexToken.isEmpty else {
            isLoggedIn = false
            return
        }

        // If we have both IP and token, consider logged in
        isLoggedIn = true

        // Then verify the token works by calling server capabilities
        Task {
            do {
                _ = try await getServerCapabilities()
                // Token is valid, keep logged in status
            } catch {
                // Only clear token if it's actually invalid (401), not for network issues
                if let plexError = error as? PlexError, case .invalidToken = plexError {
                    await MainActor.run {
                        isLoggedIn = false
                        settings.plexToken = ""
                        settings.tokenExpirationDate = nil
                        saveSettings()
                    }
                }
                // For other errors (network issues, server unreachable), keep the token
                print("⚠️ Token validation failed but keeping token: \(error.localizedDescription)")
            }
        }
    }

    func logout() {
        settings.plexToken = ""
        settings.username = ""
        settings.tokenExpirationDate = nil
        saveSettings()
        isLoggedIn = false
        isDemoMode = false
        serverCapabilities = nil
        activities = nil
        sessions = nil
        movieMetadata = nil
        print("🚪 User logged out and credentials cleared")
    }

    // MARK: - Server Capabilities
    func getServerCapabilities() async throws -> PlexCapabilitiesResponse {
        if isDemoMode {
            return demoService.createMockServerCapabilities()
        }
        
        guard !settings.serverIP.isEmpty, !settings.plexToken.isEmpty else {
            throw PlexError.notAuthenticated
        }

        // Try HTTPS first (recommended for external connections), then fallback to HTTP
        let protocols = ["https", "http"]
        var lastError: Error?

        for urlProtocol in protocols {
            let urlString = "\(urlProtocol)://\(settings.serverIP):32400/?X-Plex-Token=\(settings.plexToken)"
            guard let url = URL(string: urlString) else {
                print("❌ Invalid URL: \(urlString)")
                continue
            }

            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10.0 // Shorter timeout for external connections

            print("🏠 Checking server capabilities...")
            print("📍 URL: \(urlString)")

            do {
                let (data, response) = try await urlSession.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid response type")
                    throw PlexError.invalidResponse
                }

                print("📊 Server response status: \(httpResponse.statusCode)")

                if httpResponse.statusCode == 401 {
                    print("❌ Server returned 401 - Token invalid or expired")
                    throw PlexError.invalidToken
                }

                guard httpResponse.statusCode == 200 else {
                    print("❌ Server error: \(httpResponse.statusCode)")
                    print("📄 Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
                    throw PlexError.serverError(httpResponse.statusCode)
                }

                print("✅ Server capabilities received successfully via \(urlProtocol.uppercased())")
                print("📄 Raw response data: \(String(data: data, encoding: .utf8) ?? "nil")")

                let capabilities = try JSONDecoder().decode(PlexCapabilitiesResponse.self, from: data)
                await MainActor.run {
                    self.serverCapabilities = capabilities
                }
                return capabilities

            } catch let error as PlexError {
                lastError = error
                // If it's a token error, don't try other protocols
                if case .invalidToken = error {
                    throw error
                }
                print("⚠️ Failed with \(urlProtocol.uppercased()): \(error.localizedDescription)")
                continue
            } catch {
                lastError = error
                print("⚠️ Failed with \(urlProtocol.uppercased()): \(error.localizedDescription)")
                continue
            }
        }

        // If we get here, both protocols failed
        throw lastError ?? PlexError.invalidResponse
    }

    func fetchServerCapabilities() async {
        if isDemoMode {
            print("🎬 Demo mode: Skipping server capabilities fetch, using mock data")
            return
        }
        
        isLoading = true
        errorMessage = nil

        do {
            _ = try await getServerCapabilities()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Activities
    func getActivities() async throws -> PlexActivitiesResponse {
        if isDemoMode {
            return demoService.createMockActivitiesResponse()
        }
        
        guard !settings.serverIP.isEmpty, !settings.plexToken.isEmpty else {
            throw PlexError.notAuthenticated
        }

        // Try HTTPS first (recommended for external connections), then fallback to HTTP
        let protocols = ["https", "http"]
        var lastError: Error?

        for urlProtocol in protocols {
            let urlString = "\(urlProtocol)://\(settings.serverIP):32400/activities/?X-Plex-Token=\(settings.plexToken)"
            guard let url = URL(string: urlString) else {
                print("❌ Invalid URL: \(urlString)")
                continue
            }

            var request = URLRequest(url: url)
            request.setValue("application/xml", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10.0 // Shorter timeout for external connections

            print("🔄 Fetching server activities...")
            print("📍 URL: \(urlString)")

            do {
                let (data, response) = try await urlSession.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid response type")
                    throw PlexError.invalidResponse
                }

                print("📊 Activities response status: \(httpResponse.statusCode)")

                if httpResponse.statusCode == 401 {
                    print("❌ Server returned 401 - Token invalid or expired")
                    throw PlexError.invalidToken
                }

                guard httpResponse.statusCode == 200 else {
                    print("❌ Server error: \(httpResponse.statusCode)")
                    print("📄 Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
                    throw PlexError.serverError(httpResponse.statusCode)
                }

                print("✅ Activities received successfully via \(urlProtocol.uppercased())")
                print("📄 Raw response data: \(String(data: data, encoding: .utf8) ?? "nil")")

                let activitiesResponse = try parseActivitiesXML(data: data)
                await MainActor.run {
                    self.activities = activitiesResponse
                }
                return activitiesResponse

            } catch let error as PlexError {
                lastError = error
                // If it's a token error, don't try other protocols
                if case .invalidToken = error {
                    throw error
                }
                print("⚠️ Failed with \(urlProtocol.uppercased()): \(error.localizedDescription)")
                continue
            } catch {
                lastError = error
                print("⚠️ Failed with \(urlProtocol.uppercased()): \(error.localizedDescription)")
                continue
            }
        }

        // If we get here, both protocols failed
        throw lastError ?? PlexError.invalidResponse
    }

    func fetchActivities() async {
        if isDemoMode {
            print("🎬 Demo mode: Skipping activities fetch, using mock data")
            return
        }
        
        isLoading = true
        errorMessage = nil

        do {
            _ = try await getActivities()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Sessions
    func getSessions() async throws -> PlexSessionsResponse {
        if isDemoMode {
            return demoService.createMockSessionsResponse()
        }
        
        guard !settings.serverIP.isEmpty, !settings.plexToken.isEmpty else {
            throw PlexError.notAuthenticated
        }

        // Try HTTPS first (recommended for external connections), then fallback to HTTP
        let protocols = ["https", "http"]
        var lastError: Error?

        for urlProtocol in protocols {
            let urlString = "\(urlProtocol)://\(settings.serverIP):32400/status/sessions?X-Plex-Token=\(settings.plexToken)"
            guard let url = URL(string: urlString) else {
                print("❌ Invalid URL: \(urlString)")
                continue
            }

            // Create a fresh request for each attempt
            var request = URLRequest(url: url)
            request.setValue("application/xml", forHTTPHeaderField: "Accept")
            request.setValue("RoleCall/1.0", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 10.0 // Shorter timeout for external connections
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

            print("🎬 Fetching server sessions...")
            print("📍 URL: \(urlString)")

            do {
                let (data, response) = try await urlSession.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid response type")
                    throw PlexError.invalidResponse
                }

                print("📊 Sessions response status: \(httpResponse.statusCode)")

                if httpResponse.statusCode == 401 {
                    print("❌ Server returned 401 - Token invalid or expired")
                    throw PlexError.invalidToken
                }

                guard httpResponse.statusCode == 200 else {
                    print("❌ Server error: \(httpResponse.statusCode)")
                    print("📄 Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
                    throw PlexError.serverError(httpResponse.statusCode)
                }

                print("✅ Sessions received successfully via \(urlProtocol.uppercased())")
                print("📄 Raw response data: \(String(data: data, encoding: .utf8) ?? "nil")")

                let sessionsResponse = try parseSessionsXML(data: data)
                await MainActor.run {
                    self.sessions = sessionsResponse
                }
                return sessionsResponse

            } catch let error as PlexError {
                lastError = error
                // If it's a token error, don't try other protocols
                if case .invalidToken = error {
                    throw error
                }
                print("⚠️ Failed with \(urlProtocol.uppercased()): \(error.localizedDescription)")
                continue
            } catch {
                lastError = error
                print("⚠️ Failed with \(urlProtocol.uppercased()): \(error.localizedDescription)")
                continue
            }
        }

        // If we get here, both protocols failed
        throw lastError ?? PlexError.invalidResponse
    }

    func fetchSessions() async {
        if isDemoMode {
            print("🎬 Demo mode: Skipping session fetch, using mock data")
            await MainActor.run {
                self.sessions = demoService.createMockSessionsResponse()
                self.isLoading = false
                self.errorMessage = nil
            }
            return
        }
        
        // Cancel any existing sessions fetch task
        currentSessionsTask?.cancel()

        // Create a new task for fetching sessions
        currentSessionsTask = Task {
            await performSessionsFetch()
        }

        // Wait for the task to complete
        await currentSessionsTask?.value
    }

    private func performSessionsFetch() async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        // Retry mechanism for network requests
        let maxRetries = 3
        var lastError: Error?

        for attempt in 1...maxRetries {
            // Check if the task was cancelled
            if Task.isCancelled {
                print("🔄 Sessions fetch cancelled")
                await MainActor.run {
                    self.isLoading = false
                }
                return
            }

            do {
                _ = try await getSessions()
                // Success - clear any previous error and exit retry loop
                await MainActor.run {
                    self.errorMessage = nil
                    self.isLoading = false
                }
                return
            } catch {
                lastError = error

                // Check if this is a specific network error that we should retry
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost, .timedOut:
                        print("🔄 Network error on attempt \(attempt)/\(maxRetries): \(urlError.localizedDescription)")

                        if attempt < maxRetries {
                            // Progressive delay: 1s, 2s, 3s
                            let delaySeconds = attempt
                            print("   Retrying in \(delaySeconds) second(s)...")
                            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                            continue
                        }
                    case .cancelled:
                        // Don't retry cancelled requests
                        print("🔄 Request was cancelled, not retrying")
                        await MainActor.run {
                            self.isLoading = false
                        }
                        return
                    default:
                        // For other URL errors, don't retry
                        break
                    }
                }

                // For non-URL errors or non-retryable errors, break immediately
                break
            }
        }

        await MainActor.run {
            if let lastError = lastError {
                self.errorMessage = lastError.localizedDescription
            }
            self.isLoading = false
        }
    }

    // MARK: - Movie Metadata
    func getMovieMetadata(ratingKey: String) async throws -> PlexMovieMetadataResponse {
        if isDemoMode {
            return demoService.createMockMovieMetadata()
        }
        
        guard !settings.serverIP.isEmpty, !settings.plexToken.isEmpty else {
            throw PlexError.notAuthenticated
        }

        // Try HTTPS first (recommended for external connections), then fallback to HTTP
        let protocols = ["https", "http"]
        var lastError: Error?

        for urlProtocol in protocols {
            let urlString = "\(urlProtocol)://\(settings.serverIP):32400/library/metadata/\(ratingKey)?X-Plex-Token=\(settings.plexToken)&includeGuids=1"
            guard let url = URL(string: urlString) else {
                print("❌ Invalid URL: \(urlString)")
                continue
            }

            var request = URLRequest(url: url)
            request.setValue("application/xml", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 10.0 // Shorter timeout for external connections

            print("🎬 Fetching movie metadata...")
            print("📍 URL: \(urlString)")

            do {
                let (data, response) = try await urlSession.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Invalid response type")
                    throw PlexError.invalidResponse
                }

                print("📊 Movie metadata response status: \(httpResponse.statusCode)")

                if httpResponse.statusCode == 401 {
                    print("❌ Server returned 401 - Token invalid or expired")
                    throw PlexError.invalidToken
                }

                guard httpResponse.statusCode == 200 else {
                    print("❌ Server error: \(httpResponse.statusCode)")
                    print("📄 Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
                    throw PlexError.serverError(httpResponse.statusCode)
                }

                print("✅ Movie metadata received successfully via \(urlProtocol.uppercased())")
                print("📄 Raw response data: \(String(data: data, encoding: .utf8) ?? "nil")")

                let metadataResponse = try parseMovieMetadataXML(data: data)
                await MainActor.run {
                    self.movieMetadata = metadataResponse
                }
                return metadataResponse

            } catch let error as PlexError {
                lastError = error
                // If it's a token error, don't try other protocols
                if case .invalidToken = error {
                    throw error
                }
                print("⚠️ Failed with \(urlProtocol.uppercased()): \(error.localizedDescription)")
                continue
            } catch {
                lastError = error
                print("⚠️ Failed with \(urlProtocol.uppercased()): \(error.localizedDescription)")
                continue
            }
        }

        // If we get here, both protocols failed
        throw lastError ?? PlexError.invalidResponse
    }

    func fetchMovieMetadata(ratingKey: String) async {
        isLoading = true
        errorMessage = nil

        do {
            _ = try await getMovieMetadata(ratingKey: ratingKey)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Helper Methods
    var hasActiveSessions: Bool {
        guard let sessions = sessions else { return false }
        return sessions.mediaContainer.size > 0
    }

    var activeVideoSessions: [VideoSession] {
        return sessions?.mediaContainer.video ?? []
    }

    var activeTrackSessions: [TrackSession] {
        return sessions?.mediaContainer.track ?? []
    }

    // MARK: - XML Parsing
    private func parseActivitiesXML(data: Data) throws -> PlexActivitiesResponse {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            print("❌ Unable to convert data to string")
            throw PlexError.invalidResponse
        }

        print("🔍 Parsing XML: \(xmlString)")

        let parser = XMLParser(data: data)
        let delegate = ActivitiesXMLParserDelegate()
        parser.delegate = delegate

        if parser.parse() {
            if let response = delegate.activitiesResponse {
                return response
            } else {
                print("❌ No activities response parsed")
                throw PlexError.invalidResponse
            }
        } else {
            print("❌ XML parsing failed")
            throw PlexError.invalidResponse
        }
    }

    private func parseMovieMetadataXML(data: Data) throws -> PlexMovieMetadataResponse {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            print("❌ Unable to convert data to string")
            throw PlexError.invalidResponse
        }

        print("🔍 Parsing Movie Metadata XML: \(xmlString)")

        let parser = XMLParser(data: data)
        let delegate = MovieMetadataXMLParserDelegate()
        parser.delegate = delegate

        if parser.parse() {
            if let response = delegate.movieMetadataResponse {
                return response
            } else {
                print("❌ No movie metadata response parsed")
                throw PlexError.invalidResponse
            }
        } else {
            print("❌ XML parsing failed")
            throw PlexError.invalidResponse
        }
    }

    private func parseSessionsXML(data: Data) throws -> PlexSessionsResponse {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            print("❌ Unable to convert data to string")
            throw PlexError.invalidResponse
        }

        print("🔍 Parsing Sessions XML: \(xmlString)")

        let parser = XMLParser(data: data)
        let delegate = SessionsXMLParserDelegate()
        parser.delegate = delegate

        if parser.parse() {
            if let response = delegate.sessionsResponse {
                return response
            } else {
                print("❌ No sessions response parsed")
                throw PlexError.invalidResponse
            }
        } else {
            print("❌ Sessions XML parsing failed")
            throw PlexError.invalidResponse
        }
    }
}

// MARK: - XML Parser Delegate for Activities
class ActivitiesXMLParserDelegate: NSObject, XMLParserDelegate {
    var activitiesResponse: PlexActivitiesResponse?
    var currentActivity: PlexActivitiesResponse.ActivitiesContainer.Activity?
    var currentContext: PlexActivitiesResponse.ActivitiesContainer.Activity.Context?
    var activities: [PlexActivitiesResponse.ActivitiesContainer.Activity] = []
    var contexts: [PlexActivitiesResponse.ActivitiesContainer.Activity.Context] = []
    var containerSize: Int = 0

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {

        switch elementName {
        case "MediaContainer":
            containerSize = Int(attributeDict["size"] ?? "0") ?? 0

        case "Activity":
            let id = attributeDict["uuid"] ?? ""
            let type = attributeDict["type"]
            let cancellable = Int(attributeDict["cancellable"] ?? "0")
            let userID = Int(attributeDict["userID"] ?? "0")
            let title = attributeDict["title"]
            let subtitle = attributeDict["subtitle"]
            let progress = Int(attributeDict["progress"] ?? "0")

            currentActivity = PlexActivitiesResponse.ActivitiesContainer.Activity(
                id: id,
                type: type,
                cancellable: cancellable,
                userID: userID,
                title: title,
                subtitle: subtitle,
                progress: progress,
                context: nil // Will be set later
            )
            contexts = [] // Reset contexts for this activity

        case "Context":
            let librarySectionID = attributeDict["librarySectionID"]
            let context = PlexActivitiesResponse.ActivitiesContainer.Activity.Context(
                librarySectionID: librarySectionID
            )
            contexts.append(context)

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "Activity":
            if var activity = currentActivity {
                // Set contexts if we have any
                if !contexts.isEmpty {
                    activity = PlexActivitiesResponse.ActivitiesContainer.Activity(
                        id: activity.id,
                        type: activity.type,
                        cancellable: activity.cancellable,
                        userID: activity.userID,
                        title: activity.title,
                        subtitle: activity.subtitle,
                        progress: activity.progress,
                        context: contexts
                    )
                }
                activities.append(activity)
            }
            currentActivity = nil

        case "MediaContainer":
            let container = PlexActivitiesResponse.ActivitiesContainer(
                size: containerSize,
                activity: activities.isEmpty ? nil : activities
            )
            activitiesResponse = PlexActivitiesResponse(mediaContainer: container)

        default:
            break
        }
    }
}

// MARK: - XML Parser Delegate for Sessions
class SessionsXMLParserDelegate: NSObject, XMLParserDelegate {
    var sessionsResponse: PlexSessionsResponse?
    var containerSize: Int = 0
    var videoSessions: [VideoSession] = []
    var trackSessions: [TrackSession] = []

    // Current session being parsed
    var currentVideoSession: VideoSession?
    var currentTrackSession: TrackSession?
    var currentUser: SessionUser?
    var currentPlayer: SessionPlayer?
    var currentTranscodeSession: TranscodeSession?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {

        switch elementName {
        case "MediaContainer":
            containerSize = Int(attributeDict["size"] ?? "0") ?? 0

        case "Video":
            let id = attributeDict["ratingKey"] ?? ""
            let sessionKey = attributeDict["sessionKey"]
            let title = attributeDict["title"]
            let year = Int(attributeDict["year"] ?? "0")
            let duration = Int(attributeDict["duration"] ?? "0")
            let viewOffset = Int(attributeDict["viewOffset"] ?? "0")

            currentVideoSession = VideoSession(
                id: id,
                sessionKey: sessionKey,
                title: title,
                year: year,
                duration: duration,
                viewOffset: viewOffset,
                user: nil,
                player: nil,
                transcodeSession: nil
            )

        case "Track":
            let id = attributeDict["ratingKey"] ?? ""
            let sessionKey = attributeDict["sessionKey"]
            let title = attributeDict["title"]
            let parentTitle = attributeDict["parentTitle"]
            let grandparentTitle = attributeDict["grandparentTitle"]
            let duration = Int(attributeDict["duration"] ?? "0")
            let viewOffset = Int(attributeDict["viewOffset"] ?? "0")

            currentTrackSession = TrackSession(
                id: id,
                sessionKey: sessionKey,
                title: title,
                parentTitle: parentTitle,
                grandparentTitle: grandparentTitle,
                duration: duration,
                viewOffset: viewOffset,
                user: nil,
                player: nil
            )

        case "User":
            let id = Int(attributeDict["id"] ?? "0") ?? 0
            let title = attributeDict["title"] ?? ""
            let thumb = attributeDict["thumb"]

            currentUser = SessionUser(id: id, title: title, thumb: thumb)

        case "Player":
            let address = attributeDict["address"]
            let device = attributeDict["device"]
            let platform = attributeDict["platform"]
            let product = attributeDict["product"]
            let state = attributeDict["state"]
            let title = attributeDict["title"]
            let version = attributeDict["version"]

            currentPlayer = SessionPlayer(
                address: address,
                device: device,
                platform: platform,
                product: product,
                state: state,
                title: title,
                version: version
            )

        case "TranscodeSession":
            let key = attributeDict["key"]
            let progress = Double(attributeDict["progress"] ?? "0")
            let speed = Double(attributeDict["speed"] ?? "0")
            let duration = Int(attributeDict["duration"] ?? "0")
            let videoDecision = attributeDict["videoDecision"]
            let audioDecision = attributeDict["audioDecision"]
            let container = attributeDict["container"]
            let videoCodec = attributeDict["videoCodec"]
            let audioCodec = attributeDict["audioCodec"]

            currentTranscodeSession = TranscodeSession(
                key: key,
                progress: progress,
                speed: speed,
                duration: duration,
                videoDecision: videoDecision,
                audioDecision: audioDecision,
                container: container,
                videoCodec: videoCodec,
                audioCodec: audioCodec
            )

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "Video":
            if var session = currentVideoSession {
                // Update session with user, player, and transcode info
                session = VideoSession(
                    id: session.id,
                    sessionKey: session.sessionKey,
                    title: session.title,
                    year: session.year,
                    duration: session.duration,
                    viewOffset: session.viewOffset,
                    user: currentUser,
                    player: currentPlayer,
                    transcodeSession: currentTranscodeSession
                )
                videoSessions.append(session)
            }
            currentVideoSession = nil
            currentUser = nil
            currentPlayer = nil
            currentTranscodeSession = nil

        case "Track":
            if var session = currentTrackSession {
                session = TrackSession(
                    id: session.id,
                    sessionKey: session.sessionKey,
                    title: session.title,
                    parentTitle: session.parentTitle,
                    grandparentTitle: session.grandparentTitle,
                    duration: session.duration,
                    viewOffset: session.viewOffset,
                    user: currentUser,
                    player: currentPlayer
                )
                trackSessions.append(session)
            }
            currentTrackSession = nil
            currentUser = nil
            currentPlayer = nil

        case "MediaContainer":
            let container = PlexSessionsResponse.SessionsContainer(
                size: containerSize,
                video: videoSessions.isEmpty ? nil : videoSessions,
                track: trackSessions.isEmpty ? nil : trackSessions
            )
            sessionsResponse = PlexSessionsResponse(mediaContainer: container)

        default:
            break
        }
    }
}

class MovieMetadataXMLParserDelegate: NSObject, XMLParserDelegate {
    var movieMetadataResponse: PlexMovieMetadataResponse?
    private var currentMovie: MovieMetadata?
    private var currentRole: MovieRole?
    private var currentElement = ""
    private var containerSize = 0
    private var roles: [MovieRole] = []
    private var ratings: [MovieRating] = []
    private var guids: [MovieGuid] = []
    private var genres: [MovieGenre] = []
    private var countries: [MovieCountry] = []
    private var movies: [MovieMetadata] = []

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName

        switch elementName {
        case "MediaContainer":
            containerSize = Int(attributeDict["size"] ?? "0") ?? 0

        case "Video":
            let id = attributeDict["ratingKey"] ?? ""
            let title = attributeDict["title"]
            let year = Int(attributeDict["year"] ?? "0")
            let studio = attributeDict["studio"]
            let summary = attributeDict["summary"]
            let rating = Double(attributeDict["rating"] ?? "0")
            let audienceRating = Double(attributeDict["audienceRating"] ?? "0")
            let contentRating = attributeDict["contentRating"]
            let duration = Int(attributeDict["duration"] ?? "0")
            let tagline = attributeDict["tagline"]
            let thumb = attributeDict["thumb"]
            let art = attributeDict["art"]
            let originallyAvailableAt = attributeDict["originallyAvailableAt"]

            currentMovie = MovieMetadata(
                id: id,
                title: title,
                year: year,
                studio: studio,
                summary: summary,
                rating: rating,
                audienceRating: audienceRating,
                audienceRatingImage: nil,
                contentRating: contentRating,
                duration: duration,
                tagline: tagline,
                thumb: thumb,
                art: art,
                originallyAvailableAt: originallyAvailableAt,
                guid: nil, // Will be parsed from XML attributes if present
                roles: [],
                directors: [],
                writers: [],
                genres: [],
                countries: [],
                ratings: [],
                guids: nil, // Will be populated from Guid elements if present
                ultraBlurColors: nil
            )
            roles = []
            ratings = []
            genres = []
            countries = []

        case "Role":
            let id = attributeDict["id"] ?? ""
            let tag = attributeDict["tag"] ?? ""
            let role = attributeDict["role"]
            let thumb = attributeDict["thumb"]

            currentRole = MovieRole(id: id, tag: tag, role: role, thumb: thumb)

        case "Rating":
            print("🔍 DEBUG: Parsing Rating element with attributes: \(attributeDict)")

            let id = attributeDict["id"]
            let image = attributeDict["image"]
            let type = attributeDict["type"]
            let value = Double(attributeDict["value"] ?? "0")
            let count = Int(attributeDict["count"] ?? "0")

            let rating = MovieRating(
                id: id,
                image: image,
                type: type,
                value: value,
                count: count
            )

            print("🔍 DEBUG: Created rating: image=\(rating.image ?? "nil"), type=\(rating.type ?? "nil"), value=\(rating.value?.description ?? "nil"), count=\(rating.count?.description ?? "nil")")

            ratings.append(rating)

        case "Guid":
            let id = attributeDict["id"] ?? ""
            let guid = MovieGuid(id: id)
            guids.append(guid)
            print("🔍 DEBUG: Parsed Guid: \(id)")

        case "Genre":
            let id = attributeDict["id"] ?? ""
            let tag = attributeDict["tag"] ?? ""
            
            let genre = MovieGenre(id: id, tag: tag)
            genres.append(genre)
            print("🎭 DEBUG: Parsed Genre: id=\(id), tag=\(tag)")

        case "Country":
            let id = attributeDict["id"] ?? ""
            let tag = attributeDict["tag"] ?? ""
            
            let country = MovieCountry(id: id, tag: tag)
            countries.append(country)
            print("🌍 DEBUG: Parsed Country: id=\(id), tag=\(tag)")

        case "UltraBlurColors":
            let topLeft = attributeDict["topLeft"]
            let topRight = attributeDict["topRight"]
            let bottomLeft = attributeDict["bottomLeft"]
            let bottomRight = attributeDict["bottomRight"]

            let ultraBlurColors = UltraBlurColors(
                bottomLeft: bottomLeft,
                bottomRight: bottomRight,
                topLeft: topLeft,
                topRight: topRight
            )

            // Update the current movie with ultra blur colors
            if var movie = currentMovie {
                movie = MovieMetadata(
                    id: movie.id,
                    title: movie.title,
                    year: movie.year,
                    studio: movie.studio,
                    summary: movie.summary,
                    rating: movie.rating,
                    audienceRating: movie.audienceRating,
                    audienceRatingImage: movie.audienceRatingImage,
                    contentRating: movie.contentRating,
                    duration: movie.duration,
                    tagline: movie.tagline,
                    thumb: movie.thumb,
                    art: movie.art,
                    originallyAvailableAt: movie.originallyAvailableAt,
                    guid: movie.guid,
                    roles: movie.roles,
                    directors: movie.directors,
                    writers: movie.writers,
                    genres: movie.genres,
                    countries: movie.countries,
                    ratings: movie.ratings,
                    guids: movie.guids,
                    ultraBlurColors: ultraBlurColors
                )
                currentMovie = movie
            }

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "Role":
            if let role = currentRole {
                roles.append(role)
            }
            currentRole = nil

        case "Video":
            if var movie = currentMovie {
                movie = MovieMetadata(
                    id: movie.id,
                    title: movie.title,
                    year: movie.year,
                    studio: movie.studio,
                    summary: movie.summary,
                    rating: movie.rating,
                    audienceRating: movie.audienceRating,
                    audienceRatingImage: movie.audienceRatingImage,
                    contentRating: movie.contentRating,
                    duration: movie.duration,
                    tagline: movie.tagline,
                    thumb: movie.thumb,
                    art: movie.art,
                    originallyAvailableAt: movie.originallyAvailableAt,
                    guid: movie.guid,
                    roles: roles,
                    directors: movie.directors,
                    writers: movie.writers,
                    genres: genres.isEmpty ? nil : genres,
                    countries: countries.isEmpty ? nil : countries,
                    ratings: ratings,
                    guids: guids.isEmpty ? nil : guids,
                    ultraBlurColors: movie.ultraBlurColors
                )
                movies.append(movie)
                print("🎬 DEBUG: Movie completed with \(genres.count) genres and \(countries.count) countries")
            }
            currentMovie = nil
            roles = []
            ratings = []
            guids = []
            genres = []
            countries = []

        case "MediaContainer":
            let container = PlexMovieMetadataResponse.MovieMetadataContainer(
                size: containerSize,
                video: movies.isEmpty ? nil : movies
            )
            movieMetadataResponse = PlexMovieMetadataResponse(mediaContainer: container)

        default:
            break
        }
    }
}

// MARK: - Plex Errors
enum PlexError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidCredentials
    case invalidToken
    case notAuthenticated
    case validationError(String)
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidCredentials:
            return "Invalid username or password"
        case .invalidToken:
            return "Invalid or expired token"
        case .notAuthenticated:
            return "Not authenticated. Please log in first."
        case .validationError(let message):
            return "Validation error: \(message)"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}

// MARK: - URL Session Delegate for handling SSL certificates
class PlexURLSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        print("🔒 SSL Challenge received for: \(challenge.protectionSpace.host)")
        print("🔒 Authentication method: \(challenge.protectionSpace.authenticationMethod)")

        // Allow certificates for Plex servers, including hostname mismatches
        // This is common when accessing Plex externally with HTTPS via IP address
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            guard let serverTrust = challenge.protectionSpace.serverTrust else {
                print("⚠️ No server trust found")
                completionHandler(.performDefaultHandling, nil)
                return
            }

            // Check if this is a Plex relay certificate (*.plex.direct) first
            // These are legitimate certificates but cause hostname mismatch when accessed via IP
            var isPlexDirectCert = false
            if let certChain = SecTrustCopyCertificateChain(serverTrust),
               CFArrayGetCount(certChain) > 0,
               let cert = CFArrayGetValueAtIndex(certChain, 0) {
                let certRef = unsafeBitCast(cert, to: SecCertificate.self)
                var commonName: CFString?
                if SecCertificateCopyCommonName(certRef, &commonName) == errSecSuccess,
                   let commonName = commonName as String?,
                   commonName.contains("plex.direct") {
                    isPlexDirectCert = true
                    print("🔍 Detected Plex relay certificate: \(commonName)")
                }
            }

            if isPlexDirectCert {
                // This is a legitimate Plex relay certificate - accept it unconditionally
                let credential = URLCredential(trust: serverTrust)
                print("✅ Accepting Plex relay certificate (*.plex.direct) for IP access")
                completionHandler(.useCredential, credential)
            } else {
                // For external Plex servers, we need to handle hostname mismatches
                // Create a policy that doesn't check hostname (since we're connecting via IP)
                let policy = SecPolicyCreateBasicX509()
                SecTrustSetPolicies(serverTrust, policy)

                // Evaluate the trust without hostname validation
                var error: CFError?
                let isValid = SecTrustEvaluateWithError(serverTrust, &error)

                if isValid {
                    // Certificate chain is valid, create credential
                    let credential = URLCredential(trust: serverTrust)
                    print("✅ Accepting SSL certificate for external Plex server (hostname validation bypassed)")
                    completionHandler(.useCredential, credential)
                } else {
                    let errorDescription = error?.localizedDescription ?? "Unknown error"
                    print("⚠️ SSL certificate validation failed: \(errorDescription)")
                    completionHandler(.performDefaultHandling, nil)
                }
            }
        } else {
            print("🔒 Using default handling for non-server-trust challenge")
            completionHandler(.performDefaultHandling, nil)
        }
    }
}