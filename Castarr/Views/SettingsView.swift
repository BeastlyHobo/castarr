//
//  SettingsView.swift
//  RoleCall
//
//  Created by Eric on 7/28/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var plexService: PlexService
    @State private var serverIP: String = ""
    @State private var showingAlert = false
    @Environment(\.dismiss) private var dismiss
    var onSettingsSaved: (() -> Void)?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Plex Server Configuration").foregroundColor(Theme.Colors.highlight)) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Server IP Address")
                            .font(.headline)
                            .foregroundColor(Theme.Colors.text)

                        TextField("Enter server IP address", text: $serverIP)
                            .textFieldStyle(.plain)
                            .font(Theme.Typography.body)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Theme.Colors.surface.opacity(0.9))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Theme.Colors.highlight.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .keyboardType(.numbersAndPunctuation)
                            .autocorrectionDisabled()
                            .foregroundColor(Theme.Colors.text)

                        Text("Enter the IP address of your Plex Media Server (port 32400 will be added automatically)")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.highlight)

                        if !serverIP.isEmpty && !isValidIPAddress(serverIP) {
                            Text("⚠️ Please enter a valid IP address (e.g., 192.168.1.100)")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.primaryAccent)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Theme.Colors.surface.opacity(0.85))

                Section(header: Text("Actions").foregroundColor(Theme.Colors.highlight)) {
                    Button("Save Settings") {
                        saveSettings()
                    }
                    .disabled(serverIP.isEmpty || !isValidIPAddress(serverIP))

                    if plexService.isLoggedIn {
                        Button("Logout", role: .destructive) {
                            plexService.logout()
                        }
                    }
                }
                .listRowBackground(Theme.Colors.surface.opacity(0.85))

                if plexService.isLoggedIn {
                    Section(header: Text("Connection Status").foregroundColor(Theme.Colors.highlight)) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.Colors.secondaryAccent)
                            Text("Connected to Plex Server")
                                .foregroundColor(Theme.Colors.text)
                        }

                        Text("Server: \(plexService.settings.serverIP)")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.highlight)
                    }
                    .listRowBackground(Theme.Colors.surface.opacity(0.85))

                    Section(header: Text("Server Information").foregroundColor(Theme.Colors.highlight)) {
                        NavigationLink(destination: ServerCapabilitiesView(plexService: plexService)) {
                            Label("Server Capabilities", systemImage: "server.rack")
                                .foregroundColor(Theme.Colors.text)
                        }

                        NavigationLink(destination: ActivitiesView(plexService: plexService)) {
                            Label("Server Activities", systemImage: "gearshape.2")
                                .foregroundColor(Theme.Colors.text)
                        }

                        NavigationLink(destination: SessionsView(plexService: plexService, selectedSessionIndex: $plexService.selectedSessionIndex)) {
                            Label("Active Sessions", systemImage: "play.circle")
                                .foregroundColor(Theme.Colors.text)
                        }
                    }
                    .listRowBackground(Theme.Colors.surface.opacity(0.85))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.Colors.background)
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Settings Saved", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text("Your Plex server settings have been saved.")
            }
        }
        .tint(Theme.Colors.primaryAccent)
        .background(Theme.Colors.background.ignoresSafeArea())
        .onAppear {
            serverIP = plexService.settings.serverIP
        }
    }

    private func saveSettings() {
        plexService.updateServerIP(serverIP)
        if let onSettingsSaved = onSettingsSaved {
            onSettingsSaved()
            dismiss()
        } else {
            showingAlert = true
        }
    }

    private func isValidIPAddress(_ ip: String) -> Bool {
        let parts = ip.components(separatedBy: ".")
        guard parts.count == 4 else { return false }

        for part in parts {
            guard let num = Int(part), num >= 0 && num <= 255 else {
                return false
            }
        }
        return true
    }
}

#Preview {
    SettingsView(plexService: PlexService())
}
