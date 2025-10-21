//
//  ContentView.swift
//  RoleCall
//
//  Created by Eric on 7/28/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var plexService = PlexService()
    @State private var showingSettings = false
    @State private var isInitialSetup = false

    var body: some View {
        NavigationView {
            Group {
                if plexService.isLoggedIn {
                    // Main app content when logged in - Now Playing focused
                    MainView(plexService: plexService)
                } else {
                    // Login view when not authenticated
                    LoginView(plexService: plexService) {
                        isInitialSetup = true
                        showingSettings = true
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isInitialSetup = false
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingSettings) {
            if isInitialSetup {
                SettingsView(plexService: plexService) {
                    isInitialSetup = false
                }
            } else {
                SettingsView(plexService: plexService)
            }
        }
    }
}

#Preview {
    ContentView()
}
