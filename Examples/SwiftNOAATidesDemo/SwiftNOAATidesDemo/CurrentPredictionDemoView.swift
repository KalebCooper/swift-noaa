import SwiftNOAATides
import SwiftNOAATidesModels
import SwiftUI

struct CurrentPredictionDemoView: View {
  @State private var bin = 14
  @State private var day = Date.now
  @State private var events: CurrentEvents?
  @State private var isLoading = false
  @State private var message: String?
  @State private var mode = CurrentPredictionMode.major
  @State private var predictions: CurrentPredictions?
  @State private var station = "EPT0003"
  @State private var stations: [CoastalStation] = []
  @State private var usesProviderDefault = false

  private let client = TidesClient(configuration: .init(application: "SwiftNOAATidesDemo"))

  var body: some View {
    List {
      Section("Current predictions") {
        TextField("Station identifier", text: $station).textInputAutocapitalization(.never)
        Button("Discover prediction stations") { Task { await loadStations() } }
        if !stations.isEmpty {
          Picker("Station", selection: $station) {
            ForEach(Array(stations.enumerated()), id: \.offset) { _, item in
              Text(item.name + " / bin " + (item.currentBin.map(String.init) ?? "unknown")).tag(
                item.identifier)
            }
          }
        }
        Toggle("Use provider default bin", isOn: $usesProviderDefault)
        if !usesProviderDefault { Stepper("Bin \(bin)", value: $bin, in: 1...999) }
        DatePicker("Day (GMT)", selection: $day, displayedComponents: .date).environment(
          \.timeZone, .gmt)
        Button("Load max and slack events") { Task { await loadEvents() } }
        Picker("Sample representation", selection: $mode) {
          Text("Major-axis velocity").tag(CurrentPredictionMode.major)
          Text("Speed and direction").tag(CurrentPredictionMode.speedAndDirection)
        }
        Button("Load hourly predictions") { Task { await loadPredictions() } }
        Text(
          "Metric: cm/s and meters. Subordinate stations support max/slack events. Actual sample representation is shown below."
        ).font(.footnote)
      }.disabled(isLoading)
      if let events {
        Section("Predicted events") {
          Text("Provider units: " + events.units)
          ForEach(Array(events.events.enumerated()), id: \.offset) { _, event in
            VStack(alignment: .leading) {
              Text(event.time.rawValue + " GMT; " + event.kind.rawValue)
              Text("Signed major velocity: \(event.velocityMajor); bin " + event.bin)
              Text("Mean ebb: \(event.meanEbbDirection)°; flood: \(event.meanFloodDirection)°")
            }
          }
          if events.events.isEmpty { Text("No events in this response.") }
        }
      }
      if let predictions {
        Section("Predicted hourly samples") {
          Text("Provider units: " + predictions.units)
          ForEach(Array(predictions.predictions.enumerated()), id: \.offset) { _, value in
            VStack(alignment: .leading) {
              Text(value.time.rawValue + " GMT; bin " + value.bin)
              switch value.velocity {
              case .major(let ebb, let flood, let velocity):
                Text("Signed major velocity: \(velocity); mean ebb: \(ebb)°; flood: \(flood)°")
              case .speedAndDirection(let direction, let speed):
                Text("Speed: " + speed.rawValue + "; direction: \(direction)°")
              }
              Text("Depth: " + (value.depth?.rawValue ?? "not reported"))
            }
          }
          if predictions.predictions.isEmpty { Text("No samples in this response.") }
        }
      }
      if isLoading { ProgressView() }
      if let message { Text(message).foregroundStyle(.secondary) }
    }
    .navigationTitle("Current predictions")
    .onChange(of: station) {
      events = nil; predictions = nil
    }
    .onChange(of: day) {
      events = nil; predictions = nil
    }
    .onChange(of: bin) {
      events = nil; predictions = nil
    }
    .onChange(of: usesProviderDefault) {
      events = nil; predictions = nil
    }
    .onChange(of: mode) { predictions = nil }
  }

  private func loadEvents() async {
    isLoading = true; message = nil; events = nil
    defer { isLoading = false }
    do {
      let query = try CurrentEventQuery(
        bin: usesProviderDefault ? .providerDefault : .explicit(bin), range: range(),
        stationIdentifier: CoastalStationIdentifier(station), units: .metric)
      events = try await client.currentEvents(matching: query)
    } catch { show(error) }
  }

  private func loadPredictions() async {
    isLoading = true; message = nil; predictions = nil
    defer { isLoading = false }
    do {
      let query = try CurrentPredictionQuery(
        bin: usesProviderDefault ? .providerDefault : .explicit(bin), interval: .hourly, mode: mode,
        range: range(), stationIdentifier: CoastalStationIdentifier(station), units: .metric)
      predictions = try await client.currentPredictions(matching: query)
    } catch { show(error) }
  }

  private func loadStations() async {
    isLoading = true; message = nil
    defer { isLoading = false }
    do {
      stations = try await client.stations(matching: CoastalStationQuery(type: .currentPredictions))
        .stations
    } catch { show(error) }
  }

  private func range() throws -> TidesDateRange {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    let begin = calendar.startOfDay(for: day)
    guard let next = calendar.date(byAdding: .day, value: 1, to: begin) else {
      throw TidesQueryError.invalidDateRange
    }
    return try TidesDateRange(begin: begin, end: next.addingTimeInterval(-60))
  }

  private func show(_ error: any Error) {
    if case TidesError.provider(let refusal) = error {
      message = refusal.message
    } else if case TidesError.decoding = error {
      message =
        "NOAA returned an unsupported response for this selection. Try max/slack events for a subordinate station."
    } else {
      message = "Could not load predictions. Check the station, bin and date."
    }
  }
}
