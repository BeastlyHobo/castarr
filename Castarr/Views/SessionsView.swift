//
//  SessionsView.swift
//  RoleCall
//
//  Created by Eric on 7/28/25.
//

import SwiftUI

struct SessionsView: View {
    @ObservedObject var plexService: PlexService
    @Binding var selectedSessionIndex: Int

    var body: some View {
        Group {
            if plexService.isLoading {
                VStack {
                    ProgressView("Loading sessions...")
                        .padding()
                }
            } else if let sessionsResponse = plexService.sessions {
                sessionsContent(sessionsResponse)
            } else {
                noDataView
            }
        }
        .navigationTitle("Active Sessions")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if plexService.sessions == nil {
                Task {
                    await plexService.fetchSessions()
                }
            }
        }
    }

    private func sessionsContent(_ sessionsResponse: PlexSessionsResponse) -> some View {
        List {
            // Sessions Overview Section
            Section("Overview") {
                DetailRow(title: "Active Sessions", value: "\(sessionsResponse.mediaContainer.size)")
            }

            // Video Sessions Section
            if let videoSessions = sessionsResponse.mediaContainer.video, !videoSessions.isEmpty {
                Section("Video Sessions") {
                    ForEach(Array(videoSessions.enumerated()), id: \.element.id) { index, session in
                        VideoSessionView(
                            session: session,
                            isSelected: index == selectedSessionIndex,
                            onTap: {
                                selectedSessionIndex = index
                            }
                        )
                    }
                }
            }

            // Audio Sessions Section
            if let trackSessions = sessionsResponse.mediaContainer.track, !trackSessions.isEmpty {
                Section("Audio Sessions") {
                    ForEach(trackSessions) { session in
                        TrackSessionView(session: session)
                    }
                }
            }

            // Raw Data Section
            Section("Raw Response") {
                NavigationLink("View JSON Response") {
                    SessionsRawDataView(sessionsResponse: sessionsResponse)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .refreshable {
            await plexService.fetchSessions()
        }
    }

    private var noDataView: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Active Sessions")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Pull down to refresh and load active streaming sessions")
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

struct VideoSessionView: View {
    let session: VideoSession
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title and year
            HStack {
                if let title = session.title {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                if let year = session.year {
                    Text("(\(year))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Progress bar if available
            if let duration = session.duration, let viewOffset = session.viewOffset, duration > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(formatTime(viewOffset)) / \(formatTime(duration))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    let progressValue = min(max(Double(viewOffset), 0.0), Double(duration))
                    ProgressView(value: progressValue, total: Double(duration))
                        .progressViewStyle(LinearProgressViewStyle())
                }
            }

            // User and Player info
            VStack(alignment: .leading, spacing: 2) {
                if let user = session.user {
                    HStack {
                        Text("User:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(user.title)
                            .font(.caption)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }

                if let player = session.player {
                    HStack {
                        Text("Device:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(player.product ?? "Unknown") on \(player.platform ?? "Unknown")")
                            .font(.caption)
                            .foregroundColor(.primary)
                        Spacer()
                    }

                    if let state = player.state {
                        HStack {
                            Text("Status:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(state.capitalized)
                                .font(.caption)
                                .foregroundColor(state == "playing" ? .green : .orange)
                            Spacer()
                        }
                    }
                }

                // Transcoding info
                if let transcodeSession = session.transcodeSession {
                    HStack {
                        Text("Transcoding:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(transcodeSession.videoDecision ?? "unknown") / \(transcodeSession.audioDecision ?? "unknown")")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Spacer()
                    }

                    if let progress = transcodeSession.progress, let speed = transcodeSession.speed {
                        HStack {
                            Text("Transcode Progress:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(formatProgress(progress))% at \(formatSpeed(speed))x")
                                .font(.caption)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                }
            }

            // Session ID for debugging and selection indicator
            HStack {
                Text("Session:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(session.sessionKey ?? session.id)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, isSelected ? 8 : 0)
        .padding(.vertical, isSelected ? 8 : 0)
        .background(
            RoundedRectangle(cornerRadius: isSelected ? 12 : 8)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: isSelected ? 12 : 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: isSelected ? 2.5 : 0)
        )
        .onTapGesture {
            // Provide haptic feedback when selecting a session
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            onTap()
        }
    }
}

struct TrackSessionView: View {
    let session: TrackSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Track, album, and artist
            VStack(alignment: .leading, spacing: 2) {
                if let title = session.title {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                if let parentTitle = session.parentTitle {
                    Text(parentTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let grandparentTitle = session.grandparentTitle {
                    Text(grandparentTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar if available
            if let duration = session.duration, let viewOffset = session.viewOffset, duration > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(formatTime(viewOffset)) / \(formatTime(duration))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    let progressValue = min(max(Double(viewOffset), 0.0), Double(duration))
                    ProgressView(value: progressValue, total: Double(duration))
                        .progressViewStyle(LinearProgressViewStyle())
                }
            }

            // User and Player info
            VStack(alignment: .leading, spacing: 2) {
                if let user = session.user {
                    HStack {
                        Text("User:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(user.title)
                            .font(.caption)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }

                if let player = session.player {
                    HStack {
                        Text("Device:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(player.product ?? "Unknown") on \(player.platform ?? "Unknown")")
                            .font(.caption)
                            .foregroundColor(.primary)
                        Spacer()
                    }

                    if let state = player.state {
                        HStack {
                            Text("Status:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(state.capitalized)
                                .font(.caption)
                                .foregroundColor(state == "playing" ? .green : .orange)
                            Spacer()
                        }
                    }
                }
            }

            // Session ID for debugging
            HStack {
                Text("Session:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(session.sessionKey ?? session.id)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

struct SessionsRawDataView: View {
    let sessionsResponse: PlexSessionsResponse

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
            let data = try encoder.encode(sessionsResponse)
            return String(data: data, encoding: .utf8) ?? "Unable to format JSON"
        } catch {
            return "Error formatting JSON: \(error.localizedDescription)"
        }
    }
}

// Helper function to format time in milliseconds to mm:ss
private func formatTime(_ milliseconds: Int) -> String {
    let totalSeconds = milliseconds / 1000
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%d:%02d", minutes, seconds)
}

// Helper function to safely format progress values
private func formatProgress(_ value: Double) -> String {
    if value.isNaN || value.isInfinite {
        return "0.0"
    }
    return String(format: "%.1f", value)
}

// Helper function to safely format speed values
private func formatSpeed(_ value: Double) -> String {
    if value.isNaN || value.isInfinite {
        return "1.0"
    }
    return String(format: "%.1f", value)
}

#Preview {
    SessionsView(plexService: PlexService(), selectedSessionIndex: .constant(0))
}
