import SwiftNOAATides
import SwiftNOAATidesModels
import SwiftUI

struct CurrentDemoView: View {
  @State private var bin = 4
  @State private var bins: CurrentBins?
  @State private var day = Date.now
  @State private var isLoading = false
  @State private var message: String?
  @State private var observations: CurrentObservations?
  @State private var station = "cb0102"
  @State private var stations: [CoastalStation] = []
  @State private var usesProviderDefault = false

  private let client = TidesClient(configuration: .init(application: "SwiftNOAATidesDemo"))

  var body: some View {
    List {
      Section("Current station and bin") {
        TextField("Station identifier", text: $station).textInputAutocapitalization(.never)
        Button("Discover current stations") { Task { await loadStations() } }
        if !stations.isEmpty {
          Picker("Station", selection: $station) {
            ForEach(stations, id: \.identifier) { Text($0.name).tag($0.identifier) }
          }
        }
        Button("Load bin metadata") { Task { await loadBins() } }
        Toggle("Use provider default bin", isOn: $usesProviderDefault)
        if !usesProviderDefault { Stepper("Bin \(bin)", value: $bin, in: 1...999) }
        DatePicker("Day (GMT)", selection: $day, displayedComponents: .date).environment(
          \.timeZone, .gmt)
        Button("Load measured currents") { Task { await loadObservations() } }
      }.disabled(isLoading)
      if let bins {
        Section("Bin metadata") {
          ForEach(bins.bins ?? [], id: \.number) { item in
            Text(
              "Bin \(item.number): " + (item.depth.map(String.init(describing:)) ?? "unknown depth")
                + " " + (bins.units ?? "unknown units"))
          }
          Text(
            "Depths can change between deployments. Metadata does not establish historical depth."
          )
          .font(.footnote)
        }
      }
      if let observations {
        Section("Measured currents") {
          Text(
            "Requested station " + observations.requestedQuery.stationIdentifier.rawValue
              + "; cm/s, degrees, GMT.")
          ForEach(Array(observations.observations.enumerated()), id: \.offset) { _, value in
            VStack(alignment: .leading) {
              Text(value.time.rawValue + " GMT; bin " + value.bin)
              Text(
                (value.speed.value == nil ? "Missing speed" : value.speed.rawValue + " cm/s")
                  + "; direction "
                  + (value.direction.value == nil ? "missing" : value.direction.rawValue + "°"))
            }
          }
          if observations.observations.isEmpty { Text("No observations in this response.") }
        }
      }
      if isLoading { ProgressView() }
      if let message { Text(message).foregroundStyle(.secondary) }
    }
    .navigationTitle("Current observations")
    .onChange(of: station) {
      bins = nil; observations = nil
    }
    .onChange(of: day) { observations = nil }
    .onChange(of: bin) { observations = nil }
    .onChange(of: usesProviderDefault) { observations = nil }
  }

  private func loadBins() async {
    isLoading = true; message = nil; bins = nil
    defer { isLoading = false }
    do {
      bins = try await client.currentBins(
        stationIdentifier: CoastalStationIdentifier(station), units: .metric)
    } catch { show(error) }
  }

  private func loadObservations() async {
    isLoading = true; message = nil; observations = nil
    defer { isLoading = false }
    do {
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = .gmt
      let begin = calendar.startOfDay(for: day)
      guard let next = calendar.date(byAdding: .day, value: 1, to: begin) else { return }
      let query = try CurrentObservationQuery(
        bin: usesProviderDefault ? .providerDefault : .explicit(bin),
        range: TidesDateRange(begin: begin, end: next.addingTimeInterval(-60)),
        stationIdentifier: CoastalStationIdentifier(station), units: .metric)
      observations = try await client.currentObservations(matching: query)
    } catch { show(error) }
  }

  private func loadStations() async {
    isLoading = true; message = nil
    defer { isLoading = false }
    do {
      stations = try await client.stations(matching: CoastalStationQuery(type: .currents)).stations
    } catch { show(error) }
  }

  private func show(_ error: any Error) {
    if case TidesError.provider(let refusal) = error {
      message = refusal.message
    } else {
      message = "Could not load currents. Check the station, bin and date."
    }
  }
}
