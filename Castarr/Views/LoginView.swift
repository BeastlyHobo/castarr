//
//  LoginView.swift
//  Castarr
//
//  Created by Eric on 7/28/25.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var plexService: PlexService
    @State private var showDemoButton = false
    var onServerSettingsTap: (() -> Void)?

    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(spacing: 24) {
                        header
                        loginButton
                        demoSection
                        errorMessage
                    }
                    .themeCard(cornerRadius: 24, padding: 24)

                    serverStatusSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 72)
                .padding(.bottom, 48)
            }
        }
    }

    private var canLogin: Bool {
        !plexService.settings.serverIP.isEmpty
    }

    private var header: some View {
        VStack(spacing: 16) {
            Image(systemName: "tv.and.hifispeaker.fill")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.secondaryAccent)

            Text("Login to Plex")
                .font(Theme.Typography.title)
                .foregroundColor(Theme.Colors.text)

            Text("You'll be redirected to Plex.tv to securely log in with your account")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.highlight)
                .multilineTextAlignment(.center)
        }
    }

    private var loginButton: some View {
        Button(action: {
            Task {
                await plexService.startOAuthLogin()
            }
        }) {
            HStack {
                if plexService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.background))
                        .scaleEffect(0.9)
                }
                Image(systemName: "arrow.up.forward.app")
                Text(plexService.isLoading ? "Authenticating..." : "Login with Plex")
                    .fontWeight(.semibold)
            }
        }
        .buttonStyle(Theme.PrimaryButtonStyle())
        .disabled(!canLogin || plexService.isLoading)
        .animation(.easeInOut(duration: 0.2), value: plexService.isLoading)
    }

    @ViewBuilder
    private var demoSection: some View {
        if showDemoButton {
            VStack(spacing: 12) {
                Divider()
                    .background(Theme.Colors.surface)

                Text("Demo Account")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.highlight)

                Button(action: {
                    Task {
                        await plexService.loginDemo(email: DemoService.demoEmail)
                    }
                }) {
                    HStack {
                        if plexService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.secondaryAccent))
                                .scaleEffect(0.9)
                        }
                        Text("Login as Demo")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(Theme.SecondaryButtonStyle())
                .disabled(plexService.isLoading)
            }
        } else {
            Button("App Review? Use Demo Account") {
                withAnimation(.easeInOut) {
                    showDemoButton = true
                }
            }
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.highlight)
        }
    }

    @ViewBuilder
    private var errorMessage: some View {
        if let errorMessage = plexService.errorMessage {
            Text(errorMessage)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.error)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var serverStatusSection: some View {
        if plexService.settings.serverIP.isEmpty {
            Button(action: {
                onServerSettingsTap?()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "server.rack")
                    Text("Enter Plex Media Server IP")
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(Theme.SecondaryButtonStyle())
        } else {
            VStack(spacing: 8) {
                Text("Server: \(plexService.settings.serverIP)")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.highlight)

                if plexService.settings.serverIP.hasPrefix("10.") || plexService.settings.serverIP.hasPrefix("192.168.") || plexService.settings.serverIP.hasPrefix("172.") {
                    Text("🏠 Internal network connection")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.secondaryAccent)
                } else {
                    Text("🌐 External network connection")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.primaryAccent)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.Colors.surface.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.Colors.highlight.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
}

#Preview {
    LoginView(plexService: PlexService())
}
