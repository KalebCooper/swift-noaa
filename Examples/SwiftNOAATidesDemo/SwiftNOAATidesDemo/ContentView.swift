import Charts
import SwiftNOAATidesModels
import SwiftUI

struct ContentView: View {
  @State private var model = TidesDemoModel()
  @State private var search = ""
  @State private var showingStations = false

  var body: some View {
    NavigationStack {
      List {
        Section("Request") {
          Button {
            showingStations = true
          } label: {
            LabeledContent("Station", value: selectedStationName)
          }
          .disabled(model.isLoading)
          DatePicker("Day (GMT)", selection: $model.day, displayedComponents: .date)
            .environment(\.timeZone, .gmt)
            .disabled(model.isLoading)
          Button("Load high and low tides") {
            Task { await model.loadPredictions() }
          }
          .disabled(model.selectedStationIdentifier.isEmpty || model.isLoading)
          Button("Load hourly samples") { Task { await model.loadSamples() } }
            .disabled(model.selectedStationIdentifier.isEmpty || model.isLoading)
          Button("Load measured water levels") { Task { await model.loadWaterLevels() } }
            .disabled(model.selectedStationIdentifier.isEmpty || model.isLoading)
        }
        if let water = model.water {
          Section("Measured six-minute water levels") {
            ForEach(Array(water.observations.enumerated()), id: \.offset) { _, observation in
              VStack(alignment: .leading) {
                Text(observation.time.rawValue + " GMT")
                Text(
                  observation.height.value == nil
                    ? "Missing height" : observation.height.rawValue + " m above MLLW")
                Text("Quality: " + observation.quality.rawValue + "; flags: " + observation.flags)
                  .font(.caption).foregroundStyle(.secondary)
              }
            }
            if water.observations.isEmpty { Text("No measurements in this response.") }
          }
        }
        if let samples = model.samples {
          Section("Reported hourly samples") {
            Chart(Array(samples.predictions.enumerated()), id: \.offset) { _, sample in
              PointMark(
                x: .value("GMT time", sample.time.date),
                y: .value("Meters above MLLW", sample.height.value))
            }
            .environment(\.timeZone, .gmt)
            .frame(height: 220)
            Text("GMT, meters above MLLW. Points are reported predictions without interpolation.")
              .font(.footnote).foregroundStyle(.secondary)
          }
        }
        if model.isLoading { ProgressView("Loading NOAA data") }
        if let message = model.message {
          Section { Text(message).foregroundStyle(.secondary) }
        }
        if let result = model.result {
          Section("Predicted events") {
            if result.predictions.isEmpty { Text("No events in this response.") }
            ForEach(Array(result.predictions.enumerated()), id: \.offset) { _, event in
              VStack(alignment: .leading, spacing: 4) {
                Text(
                  event.kind == .high
                    ? "High tide" : event.kind == .low ? "Low tide" : event.kind.rawValue
                )
                .font(.headline)
                Text(event.time.rawValue + " GMT")
                Text(event.height.rawValue + " m above MLLW").foregroundStyle(.secondary)
              }
            }
          }
          Section {
            Text(
              "Requested station " + result.requestedQuery.stationIdentifier.rawValue
                + ". Predictions use meters above MLLW and GMT. Values are not measured water levels or navigation advice."
            )
            .font(.footnote).foregroundStyle(.secondary)
          }
        }
      }
      .navigationTitle("Tides & Currents")
      .task { if model.stations.isEmpty { await model.loadStations() } }
      .onChange(of: model.day) {
        model.result = nil; model.samples = nil; model.water = nil
      }
      .onChange(of: model.selectedStationIdentifier) {
        model.result = nil; model.samples = nil; model.water = nil
      }
      .sheet(isPresented: $showingStations) {
        NavigationStack {
          List(filteredStations, id: \.identifier) { station in
            Button {
              model.selectedStationIdentifier = station.identifier
              showingStations = false
            } label: {
              VStack(alignment: .leading) {
                Text(station.name)
                Text(station.identifier).font(.caption).foregroundStyle(.secondary)
              }
            }
          }
          .searchable(text: $search, prompt: "Station name or identifier")
          .navigationTitle("Choose a station")
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Cancel") { showingStations = false }
            }
            ToolbarItem(placement: .primaryAction) {
              Button("Reload") { Task { await model.loadStations() } }.disabled(model.isLoading)
            }
          }
        }
      }
    }
  }

  private var filteredStations: [CoastalStation] {
    guard !search.isEmpty else { return model.stations }
    return model.stations.filter {
      $0.name.localizedCaseInsensitiveContains(search)
        || $0.identifier.localizedCaseInsensitiveContains(search)
    }
  }

  private var selectedStationName: String {
    model.stations.first { $0.identifier == model.selectedStationIdentifier }?.name
      ?? "Choose a station"
  }
}
