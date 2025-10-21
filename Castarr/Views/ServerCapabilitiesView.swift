//
//  ServerCapabilitiesView.swift
//  RoleCall
//
//  Created by Eric on 7/28/25.
//

import SwiftUI

struct ServerCapabilitiesView: View {
    @ObservedObject var plexService: PlexService

    var body: some View {
        Group {
            if plexService.isLoading {
                VStack {
                    ProgressView("Loading server capabilities...")
                        .padding()
                }
            } else if let capabilities = plexService.serverCapabilities {
                capabilitiesContent(capabilities)
            } else {
                noDataView
            }
        }
        .navigationTitle("Server Capabilities")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if plexService.serverCapabilities == nil {
                Task {
                    await plexService.fetchServerCapabilities()
                }
            }
        }
    }

    private func capabilitiesContent(_ capabilities: PlexCapabilitiesResponse) -> some View {
        List {
            // Server Info Section
            Section("Server Information") {
                if let friendlyName = capabilities.mediaContainer.friendlyName {
                    DetailRow(title: "Server Name", value: friendlyName)
                }
                if let version = capabilities.mediaContainer.version {
                    DetailRow(title: "Version", value: version)
                }
                if let platform = capabilities.mediaContainer.platform {
                    DetailRow(title: "Platform", value: platform)
                }
                if let platformVersion = capabilities.mediaContainer.platformVersion {
                    DetailRow(title: "Platform Version", value: platformVersion)
                }
                if let machineIdentifier = capabilities.mediaContainer.machineIdentifier {
                    DetailRow(title: "Machine ID", value: machineIdentifier)
                }
            }

            // MyPlex Section
            Section("MyPlex") {
                if let myPlex = capabilities.mediaContainer.myPlex {
                    DetailRow(title: "MyPlex Enabled", value: myPlex ? "Yes" : "No")
                }
                if let myPlexUsername = capabilities.mediaContainer.myPlexUsername {
                    DetailRow(title: "MyPlex Username", value: myPlexUsername)
                }
                if let myPlexSigninState = capabilities.mediaContainer.myPlexSigninState {
                    DetailRow(title: "Signin State", value: myPlexSigninState)
                }
                if let myPlexSubscription = capabilities.mediaContainer.myPlexSubscription {
                    DetailRow(title: "Subscription", value: myPlexSubscription ? "Active" : "Inactive")
                }
            }

            // Capabilities Section
            Section("Server Capabilities") {
                if let allowCameraUpload = capabilities.mediaContainer.allowCameraUpload {
                    DetailRow(title: "Camera Upload", value: allowCameraUpload ? "Enabled" : "Disabled")
                }
                if let allowChannelAccess = capabilities.mediaContainer.allowChannelAccess {
                    DetailRow(title: "Channel Access", value: allowChannelAccess ? "Enabled" : "Disabled")
                }
                if let allowMediaDeletion = capabilities.mediaContainer.allowMediaDeletion {
                    DetailRow(title: "Media Deletion", value: allowMediaDeletion ? "Enabled" : "Disabled")
                }
                if let allowSharing = capabilities.mediaContainer.allowSharing {
                    DetailRow(title: "Sharing", value: allowSharing ? "Enabled" : "Disabled")
                }
                if let allowSync = capabilities.mediaContainer.allowSync {
                    DetailRow(title: "Sync", value: allowSync ? "Enabled" : "Disabled")
                }
                if let multiuser = capabilities.mediaContainer.multiuser {
                    DetailRow(title: "Multi-user", value: multiuser ? "Enabled" : "Disabled")
                }
            }

            // Transcoding Section
            Section("Transcoding") {
                if let transcoderAudio = capabilities.mediaContainer.transcoderAudio {
                    DetailRow(title: "Audio Transcoding", value: transcoderAudio ? "Enabled" : "Disabled")
                }
                if let transcoderVideo = capabilities.mediaContainer.transcoderVideo {
                    DetailRow(title: "Video Transcoding", value: transcoderVideo ? "Enabled" : "Disabled")
                }
                if let transcoderSubtitles = capabilities.mediaContainer.transcoderSubtitles {
                    DetailRow(title: "Subtitle Transcoding", value: transcoderSubtitles ? "Enabled" : "Disabled")
                }
                if let transcoderPhoto = capabilities.mediaContainer.transcoderPhoto {
                    DetailRow(title: "Photo Transcoding", value: transcoderPhoto ? "Enabled" : "Disabled")
                }
                if let activeVideoSessions = capabilities.mediaContainer.transcoderActiveVideoSessions {
                    DetailRow(title: "Active Video Sessions", value: "\(activeVideoSessions)")
                }
            }

            // Additional Features Section
            Section("Additional Features") {
                if let livetv = capabilities.mediaContainer.livetv {
                    DetailRow(title: "Live TV", value: livetv > 0 ? "Available" : "Not Available")
                }
                if let photoAutoTag = capabilities.mediaContainer.photoAutoTag {
                    DetailRow(title: "Photo Auto-tag", value: photoAutoTag ? "Enabled" : "Disabled")
                }
                if let voiceSearch = capabilities.mediaContainer.voiceSearch {
                    DetailRow(title: "Voice Search", value: voiceSearch ? "Enabled" : "Disabled")
                }
                if let pushNotifications = capabilities.mediaContainer.pushNotifications {
                    DetailRow(title: "Push Notifications", value: pushNotifications ? "Enabled" : "Disabled")
                }
            }

            // Raw Data Section
            Section("Raw Response") {
                NavigationLink("View JSON Response") {
                    RawDataView(capabilities: capabilities)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .refreshable {
            await plexService.fetchServerCapabilities()
        }
    }

    private var noDataView: some View {
        VStack(spacing: 20) {
            Image(systemName: "server.rack")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Server Data")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Pull down to refresh and load server capabilities")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let errorMessage = plexService.errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
    }
}

struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct RawDataView: View {
    let capabilities: PlexCapabilitiesResponse

    var body: some View {
        ScrollView {
            Text(jsonString)
                .font(.system(.caption, design: .monospaced))
                .padding()
        }
        .navigationTitle("Raw JSON")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var jsonString: String {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(capabilities)
            return String(data: data, encoding: .utf8) ?? "Unable to format JSON"
        } catch {
            return "Error formatting JSON: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ServerCapabilitiesView(plexService: PlexService())
}
