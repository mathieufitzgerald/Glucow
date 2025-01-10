//
//  MeasurementViewModel.swift
//  LibreFollow
//
//  Created by Mathieu Fitzgerald on 05.01.2025.
//

import SwiftUI

class MeasurementViewModel: ObservableObject {
    // Basic info
    @Published var patientInfo: String = ""
    @Published var measurementValue: String?
    @Published var sinceLastTrendArrow: String?
    @Published var measurementColorName: String = "gray"

    // For iOS UI
    @Published var readingTimeDisplay: String = "..."
    @Published var nextUpdateCountdown: String?
    
    // Sensor
    @Published var sensorUnixActivation: Int?
    @Published var sensorType: String?

    // We'll track if the sensor is in the 1-hour grace period
    @Published var isSensorInGracePeriod: Bool = false
    @Published var sensorReadyCountdown: String?

    private var timer: Timer?
    private var nextUpdateTimer: Timer?
    private var nextUpdateDate: Date?

    private var serverURL: String = ""
    private var useMmol: Bool = false

    // 1) The ISO8601 formatter to parse e.g. "2025-01-05T22:33:54.000Z" (with fractional seconds)
    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        // Enabling fractional seconds to handle the ".000Z" portion
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // 2) A time-only formatter for displaying local time in short style (e.g. "10:33 PM")
    private let timeOnlyFormatter: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .medium  // e.g. "2:14 PM" or "14:14"
        df.dateStyle = .none
        return df
    }()

    // MARK: - Public Start/Stop
    func start(serverURL: String, useMmol: Bool) {
        self.serverURL = serverURL
        self.useMmol   = useMmol

        // Fetch immediately
        fetchData()

        // Also schedule top-of-minute approach
        scheduleNextMinute()
        updateCountdownLoop()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        nextUpdateTimer?.invalidate()
        nextUpdateTimer = nil
    }

    // MARK: - Scheduling
    private func scheduleNextMinute() {
        let now = Date()
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        if let baseDate = calendar.date(from: comps) {
            let nextMin = baseDate.addingTimeInterval(60)
            let interval = nextMin.timeIntervalSinceNow

            self.nextUpdateDate = nextMin

            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                self?.fetchData()
                self?.scheduleNextMinute()
            }
        }
    }

    private func updateCountdownLoop() {
        nextUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            // 1) Update nextUpdateCountdown
            guard let next = self.nextUpdateDate else {
                DispatchQueue.main.async {
                    self.nextUpdateCountdown = nil
                }
                return
            }

            let diff = Int(next.timeIntervalSinceNow)
            if diff <= 0 {
                DispatchQueue.main.async {
                    self.nextUpdateCountdown = "0s"
                }
            } else {
                DispatchQueue.main.async {
                    self.nextUpdateCountdown = "\(diff)s"
                }
            }

            // 2) If the sensor is in grace period, update sensorReadyCountdown
            if self.isSensorInGracePeriod,
               let activationUnix = self.sensorUnixActivation {
                let graceEndSec = Double(activationUnix) + 3600 // 1 hour
                let nowSec = Date().timeIntervalSince1970
                let remains = graceEndSec - nowSec
                if remains <= 0 {
                    // Done with grace period
                    DispatchQueue.main.async {
                        self.isSensorInGracePeriod = false
                        self.sensorReadyCountdown = nil
                        self.fetchData()
                    }
                } else {
                    let minLeft = Int(remains / 60)
                    let secLeft = Int(remains.truncatingRemainder(dividingBy: 60))
                    DispatchQueue.main.async {
                        self.sensorReadyCountdown = "\(minLeft)m \(secLeft)s"
                    }
                }
            }
        }
    }

    // MARK: - Fetching
    private func fetchData() {
        fetchPatientInfo()
        fetchSensorInfo()
        fetchMeasurement()
    }

    private func fetchPatientInfo() {
        guard let url = URL(string: "\(serverURL)/patient-info") else { return }
        URLSession.shared.dataTask(with: url) { data, _, err in
            guard let data = data, err == nil else { return }
            if let obj = try? JSONSerialization.jsonObject(with: data, options: []),
               let dict = obj as? [String: Any] {
                let fname = dict["firstName"] as? String ?? "?"
                let lname = dict["lastName"] as? String ?? "?"
                DispatchQueue.main.async {
                    self.patientInfo = "\(fname) \(lname)"
                }
            }
        }.resume()
    }

    private func fetchSensorInfo() {
        guard let url = URL(string: "\(serverURL)/sensor-info") else { return }
        URLSession.shared.dataTask(with: url) { data, _, err in
            guard let data = data, err == nil else { return }
            if let obj = try? JSONSerialization.jsonObject(with: data, options: []),
               let dict = obj as? [String: Any] {
                let activation = dict["activationUnix"] as? Int
                self.sensorUnixActivation = activation

                let ptName = dict["ptName"] as? String
                DispatchQueue.main.async {
                    self.sensorType = ptName
                }
                // Check if <1h
                if let act = activation {
                    let nowSec = Date().timeIntervalSince1970
                    let graceEnd = Double(act) + 3600 // 1 hour
                    if nowSec < graceEnd {
                        DispatchQueue.main.async {
                            self.isSensorInGracePeriod = true
                        }
                    }
                }
            }
        }.resume()
    }

    private func fetchMeasurement() {
        let path = useMmol ? "/measurement-mmol" : "/measurement-mgdl"
        guard let url = URL(string: "\(serverURL)\(path)") else { return }

        URLSession.shared.dataTask(with: url) { data, _, err in
            guard let data = data, err == nil else { return }
            if let obj = try? JSONSerialization.jsonObject(with: data, options: []),
               let dict = obj as? [String: Any]
            {
                // The server now returns something like "2025-01-05T23:13:53.000Z"
                let isoStamp   = dict["Timestamp"] as? String ?? ""
                let arrow      = dict["SinceLastTrendArrow"] as? String ?? "N/A"
                let colorName  = dict["MeasurementColorName"] as? String ?? "gray"

                DispatchQueue.main.async {
                    // Attempt parse with ISO8601DateFormatter
                    if let parsedDate = self.isoFormatter.date(from: isoStamp) {
                        // If not in grace period, show local time
                        if !self.isSensorInGracePeriod {
                            self.readingTimeDisplay = self.timeOnlyFormatter.string(from: parsedDate)
                        } else {
                            self.readingTimeDisplay = "Not Ready"
                        }
                    } else {
                        // If parse fails, fallback to raw
                        self.readingTimeDisplay = isoStamp
                    }
                    
                    self.sinceLastTrendArrow  = arrow
                    self.measurementColorName = colorName

                    // mg/dL or mmol?
                    if self.useMmol {
                        let val = dict["ValueInMmolPerL"] as? Double ?? 0
                        self.measurementValue = String(format: "%.1f", val)
                    } else {
                        let val = dict["ValueInMgPerDl"] as? Int ?? 0
                        self.measurementValue = "\(val)"
                    }
                }
            }
        }.resume()
    }
}
