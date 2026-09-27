import Foundation
import SwiftNOAATides
import SwiftNOAATidesModels
import SwiftUI

struct CoastalObservationView: View {
  private enum Product: String, CaseIterable {
    case airPressureObservations = "air pressure"
    case airTemperatureObservations = "air temperature"
    case conductivityObservations = "conductivity"
    case humidityObservations = "humidity"
    case salinityObservations = "salinity"
    case visibilityObservations = "visibility"
    case waterTemperatureObservations = "water temperature"
    case windObservations = "wind"
  }

  @State private var day = Date.now
  @State private var identifier = "1611400"
  @State private var interval = CoastalObservationInterval.sixMinutes
  @State private var isLoading = false
  @State private var message: String?
  @State private var product = Product.waterTemperatureObservations
  @State private var rows: [String]?
  @State private var units = TidesUnits.metric

  var body: some View {
    List {
      Section("Observation request") {
        TextField("Station identifier", text: $identifier).textInputAutocapitalization(.never)
        DatePicker("Day (GMT)", selection: $day, displayedComponents: .date).environment(
          \.timeZone, .gmt)
        Picker("Product", selection: $product) {
          ForEach(Product.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
        }
        Picker("Cadence", selection: $interval) {
          Text("Six minutes").tag(CoastalObservationInterval.sixMinutes)
          Text("On the hour").tag(CoastalObservationInterval.hourly)
        }
        Picker("Units", selection: $units) {
          Text("Metric").tag(TidesUnits.metric)
          Text("English").tag(TidesUnits.english)
        }
        Button("Load selected observations") { Task { await load() } }
      }.disabled(isLoading)
      if isLoading { ProgressView() }
      if let message { Text(message) }
      if let rows {
        Section(product.rawValue.capitalized) {
          if rows.isEmpty { Text("No observations in this successful response.") }
          ForEach(Array(rows.enumerated()), id: \.offset) { _, row in Text(verbatim: row) }
        }
      }
      Text(
        "Products vary by station. Hourly selects the on-hour sample, without averaging. Missing samples remain gaps."
      )
      .font(.footnote)
    }
    .navigationTitle("Coastal observations")
    .onChange(of: day) { clear() }
    .onChange(of: identifier) { clear() }
    .onChange(of: interval) { clear() }
    .onChange(of: product) { clear() }
    .onChange(of: units) { clear() }
  }

  private func clear() { rows = nil; message = nil }

  private func format(_ value: TidesMeasurementValue, _ unit: String) -> String {
    value.value == nil ? "Missing" : value.rawValue + " " + unit
  }

  private func load() async {
    isLoading = true; clear()
    defer { isLoading = false }
    do {
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = .gmt
      let begin = calendar.startOfDay(for: day)
      guard let end = calendar.date(byAdding: .day, value: 1, to: begin) else { return }
      let query = try CoastalObservationQuery(
        interval: interval,
        range: TidesDateRange(begin: begin, end: end.addingTimeInterval(-60)),
        stationIdentifier: CoastalStationIdentifier(identifier), units: units)
      let client = TidesClient()
      switch product {
      case .airPressureObservations:
        let response = try await client.airPressureObservations(matching: query)
        rows = response.observations.map {
          $0.time.rawValue + " GMT: "
            + ($0.pressure.value == nil ? "Missing pressure" : $0.pressure.rawValue + " " + "mb")
        }
      case .airTemperatureObservations:
        let response = try await client.airTemperatureObservations(matching: query)
        rows = response.observations.map {
          $0.time.rawValue + " GMT: "
            + ($0.temperature.value == nil
              ? "Missing temperature"
              : $0.temperature.rawValue + " " + (units == .metric ? "°C" : "°F"))
        }
      case .conductivityObservations:
        let response = try await client.conductivityObservations(matching: query)
        rows = response.observations.map {
          $0.time.rawValue + " GMT: "
            + ($0.conductivity.value == nil
              ? "Missing conductivity" : $0.conductivity.rawValue + " " + "mS/cm")
        }
      case .humidityObservations:
        let response = try await client.humidityObservations(matching: query)
        rows = response.observations.map {
          $0.time.rawValue + " GMT: "
            + ($0.humidity.value == nil ? "Missing humidity" : $0.humidity.rawValue + " " + "%")
        }
      case .salinityObservations:
        let response = try await client.salinityObservations(matching: query)
        rows = response.observations.map {
          $0.time.rawValue + " GMT: salinity " + format($0.salinity, "psu") + ", specific gravity "
            + format($0.specificGravity, "(dimensionless)")
        }
      case .visibilityObservations:
        let response = try await client.visibilityObservations(matching: query)
        rows = response.observations.map {
          $0.time.rawValue + " GMT: "
            + ($0.visibility.value == nil
              ? "Missing visibility"
              : $0.visibility.rawValue + " " + (units == .metric ? "km" : "nmi"))
        }
      case .waterTemperatureObservations:
        let response = try await client.waterTemperatureObservations(matching: query)
        rows = response.observations.map {
          $0.time.rawValue + " GMT: "
            + ($0.temperature.value == nil
              ? "Missing temperature"
              : $0.temperature.rawValue + " " + (units == .metric ? "°C" : "°F"))
        }
      case .windObservations:
        let response = try await client.windObservations(matching: query)
        rows = response.observations.map {
          $0.time.rawValue + " GMT: speed " + format($0.speed, units == .metric ? "m/s" : "kn")
            + ", gust " + format($0.gust, units == .metric ? "m/s" : "kn")
            + ", from " + format($0.numericDirection, "° true") + " "
            + ($0.textDirection.isEmpty ? "(missing direction text)" : $0.textDirection)
        }
      }
    } catch let error as TidesError {
      switch error {
      case .provider(let refusal): message = refusal.message
      case .transport(.cancelled): break
      default: message = "Could not retrieve observations."
      }
    } catch { message = "Choose a valid station and GMT date." }
  }
}
