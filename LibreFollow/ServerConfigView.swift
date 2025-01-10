//
//  ServerConfigView.swift
//  LibreFollow
//
//  Created by Mathieu Fitzgerald on 05.01.2025.
//

import SwiftUI

struct ServerConfigView: View {
    @State private var serverURL: String = ""
    @State private var isMmol: Bool = false

    let onComplete: (String, Bool) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Enter your Raspberry Pi server URL")
                .font(.title3)
            TextField("e.g. https://192.168.0.10:8443", text: $serverURL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, 40)

            Toggle(isOn: $isMmol) {
                Text("Use mmol/L instead of mg/dL?")
            }
            .padding()

            Button("Start") {
                onComplete(serverURL, isMmol)
            }
            .disabled(serverURL.isEmpty)
        }
        .padding()
    }
}
