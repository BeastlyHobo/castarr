//
//  ActivitiesView.swift
//  RoleCall
//
//  Created by Eric on 7/28/25.
//

import SwiftUI

struct ActivitiesView: View {
    @ObservedObject var plexService: PlexService

    var body: some View {
        Group {
            if plexService.isLoading {
                VStack {
                    ProgressView("Loading activities...")
                        .padding()
                }
            } else if let activitiesResponse = plexService.activities {
                activitiesContent(activitiesResponse)
            } else {
                noDataView
            }
        }
        .navigationTitle("Server Activities")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if plexService.activities == nil {
                Task {
                    await plexService.fetchActivities()
                }
            }
        }
    }

    private func activitiesContent(_ activitiesResponse: PlexActivitiesResponse) -> some View {
        List {
            // Activities Overview Section
            Section("Overview") {
                DetailRow(title: "Active Activities", value: "\(activitiesResponse.mediaContainer.size)")
            }

            // Individual Activities Section
            if let activities = activitiesResponse.mediaContainer.activity, !activities.isEmpty {
                Section("Running Activities") {
                    ForEach(activities) { activity in
                        ActivityDetailView(activity: activity)
                    }
                }
            }

            // Raw Data Section
            Section("Raw Response") {
                NavigationLink("View JSON Response") {
                    ActivitiesRawDataView(activitiesResponse: activitiesResponse)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .refreshable {
            await plexService.fetchActivities()
        }
    }

    private var noDataView: some View {
        VStack(spacing: 20) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Activities Data")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Pull down to refresh and load server activities")
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

struct ActivityDetailView: View {
    let activity: PlexActivitiesResponse.ActivitiesContainer.Activity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title and subtitle
            VStack(alignment: .leading, spacing: 4) {
                if let title = activity.title {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                if let subtitle = activity.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar if available
            if let progress = activity.progress {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(formatProgress(Double(progress)))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    let safeProgress = min(max(Double(progress), 0.0), 100.0)
                    ProgressView(value: safeProgress, total: 100.0)
                        .progressViewStyle(LinearProgressViewStyle())
                }
            }

            // Activity details
            VStack(spacing: 2) {
                if let type = activity.type {
                    HStack {
                        Text("Type:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(type)
                            .font(.caption)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }

                HStack {
                    Text("Status:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(activity.isCancellable ? "Cancellable" : "Running")
                        .font(.caption)
                        .foregroundColor(activity.isCancellable ? .orange : .green)
                    Spacer()
                }

                if let userID = activity.userID {
                    HStack {
                        Text("User ID:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(userID)")
                            .font(.caption)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }

                // Context information
                if let contexts = activity.context, !contexts.isEmpty {
                    ForEach(contexts.indices, id: \.self) { index in
                        let context = contexts[index]
                        if let librarySectionID = context.librarySectionID {
                            HStack {
                                Text("Library Section:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(librarySectionID)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    }
                }
            }

            // UUID for debugging
            HStack {
                Text("ID:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(activity.id)
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

struct ActivitiesRawDataView: View {
    let activitiesResponse: PlexActivitiesResponse

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
            let data = try encoder.encode(activitiesResponse)
            return String(data: data, encoding: .utf8) ?? "Unable to format JSON"
        } catch {
            return "Error formatting JSON: \(error.localizedDescription)"
        }
    }
}

// Helper function to safely format progress values
private func formatProgress(_ value: Double) -> String {
    if value.isNaN || value.isInfinite {
        return "0.0"
    }
    return String(format: "%.1f", value)
}

#Preview {
    ActivitiesView(plexService: PlexService())
}
