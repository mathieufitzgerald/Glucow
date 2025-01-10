//
//  RootView.swift
//  LibreFollow
//
//  Created by Mathieu Fitzgerald on 05.01.2025.
//

import SwiftUI

struct RootView: View {
    @State private var isHostingChosen = false
    @State private var notHostingChosen = false

    // We check if there's a saved serverURL in UserDefaults:
    @State private var hasSavedConfig = false
    @State private var savedURL = ""
    @State private var savedIsMmol = false

    var body: some View {
        Group {
            if hasSavedConfig {
                // Jump straight to main measurement screen
                MainMeasurementView(serverURL: savedURL, useMmol: savedIsMmol)
            } else if isHostingChosen {
                // Show the configuration screen
                ServerConfigView { url, isMmol in
                    // Save to UserDefaults
                    UserDefaults.standard.set(url, forKey: "serverURL")
                    UserDefaults.standard.set(isMmol, forKey: "useMmol")
                    // Then go to main measurement
                    self.hasSavedConfig = true
                    self.savedURL = url
                    self.savedIsMmol = isMmol
                }
            } else if notHostingChosen {
                // Show "Not yet hosting" instructions
                NotHostingView()
            } else {
                // Initial screen with 2 buttons
                VStack(spacing: 20) {
                    Text("Welcome to LibreFollow")
                        .font(.title)
                    Button("Already self-hosting") {
                        isHostingChosen = true
                    }
                    Button("Not yet hosting") {
                        notHostingChosen = true
                    }
                }
                .padding()
            }
        }
        .onAppear {
            let ud = UserDefaults.standard
            if let url = ud.string(forKey: "serverURL"), !url.isEmpty {
                // We have a saved URL
                self.savedURL = url
                self.savedIsMmol = ud.bool(forKey: "useMmol") // default false if not set
                self.hasSavedConfig = true
            }
        }
    }
}

struct NotHostingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("You are not self-hosting yet, but this can still work.")
                .font(.title)
            Text("Ideally, you want to host the server yourself as this will make everything 100x easier. If you are unable to do this, you can use a third party service like Linode (Akami) to host your server. If you are still unable to host your own server, in the future, you will be able to directly enter a LibreLinkUp account into the LibreFollow app.")
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}

