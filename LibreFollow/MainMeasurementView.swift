//
//  MainMeasurementView.swift
//  LibreFollow
//
//  Created by Mathieu Fitzgerald on 05.01.2025.
//

import SwiftUI

struct MainMeasurementView: View {
    let serverURL: String
    let useMmol: Bool

    @StateObject private var viewModel = MeasurementViewModel()

    var body: some View {
        VStack {
            // Top area: reading time & "time until next update"
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Latest Reading:")
                    // The readingTime now reflects the server's timestamp or the countdown text if sensor not ready
                    Text(viewModel.readingTimeDisplay)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Next update:")
                    Text(viewModel.nextUpdateCountdown ?? "...")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
            .padding([.top, .horizontal])

            Spacer()

            if viewModel.isSensorInGracePeriod {
                // Show "Sensor ready in..." countdown
                Text("Sensor ready in:")
                    .font(.title)
                if let countdown = viewModel.sensorReadyCountdown {
                    Text(countdown)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.orange)
                } else {
                    Text("Calculating...")
                        .font(.title2)
                }
            } else {
                // Middle: measurement + arrow, with a colored underline
                if let measurementValue = viewModel.measurementValue {
                    ZStack(alignment: .bottomLeading) {
                        HStack(spacing: 8) {
                            Text(measurementValue)
                                .font(.system(size: 50, weight: .bold))

                            if let arrow = viewModel.sinceLastTrendArrow {
                                Text(arrow)
                                    .font(.system(size: 50, weight: .bold))
                            }
                        }
                        .background(
                            GeometryReader { geo in
                                ColorLineView(colorName: viewModel.measurementColorName)
                                    // Make the line exactly as wide as the HStack
                                    .frame(width: geo.size.width,
                                           height: 6)
                                    .cornerRadius(3)
                                    // SHIFT THE LINE DOWN A BIT MORE
                                    .offset(x: 0, y: geo.size.height + 2)
                            }
                        )
                    }
                } else {
                    Text("Loading... (is the server running?)")
                        .font(.title)
                }
            }

            Spacer()

            // Bottom: patient & sensor info
            VStack(spacing: 4) {
                Text("Patient: \(viewModel.patientInfo)")
                    .font(.headline)
                if let sensorType = viewModel.sensorType {
                    Text("Sensor type: \(sensorType)")
                        .font(.subheadline)
                }
                Text(sensorTimeLeftText())
                    .font(.subheadline)
            }
            .padding(.bottom, 20)
        }
        .onAppear {
            viewModel.start(serverURL: serverURL, useMmol: useMmol)
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    // Convert the "seconds left" in the sensor to a string
    func sensorTimeLeftText() -> String {
        guard let activation = viewModel.sensorUnixActivation else {
            return "Sensor info not found (maybe not activated)"
        }
        // Total lifespan: 14 days + 1 hour = 337 hours
        // 337 * 3600 = 1213200 seconds
        let lifespanSec = 337.0 * 3600.0
        let nowSec = Date().timeIntervalSince1970
        let expirySec = Double(activation) + lifespanSec
        let diff = expirySec - nowSec
        if diff <= 0 {
            return "Sensor expired, please activate a new one."
        }

        let diffDays = Int(diff / 86400)
        let remainderSec = diff.truncatingRemainder(dividingBy: 86400)
        let diffHours = Int(remainderSec / 3600)

        return "Sensor Expiry: \(diffDays) days, \(diffHours) hours"
    }
}

// A small view that draws a colored rectangle
// (We map "green" => .green, etc.)
struct ColorLineView: View {
    let colorName: String

    var body: some View {
        colorForMeasurementName(colorName)
    }

    func colorForMeasurementName(_ name: String) -> Color {
        switch name.lowercased() {
        case "green":  return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red":    return .red
        default:       return .gray
        }
    }
}
