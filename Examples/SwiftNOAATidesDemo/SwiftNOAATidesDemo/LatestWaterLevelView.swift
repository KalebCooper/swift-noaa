import SwiftNOAATides
import SwiftNOAATidesModels
import SwiftUI

struct LatestWaterLevelView: View {
  @State private var datum = "MLLW"
  @State private var identifier = "9414290"
  @State private var isLoading = false
  @State private var message: String?
  @State private var result: LatestWaterLevel?
  @State private var units = TidesUnits.metric

  var body: some View {
    List {
      Section("Latest reading request") {
        TextField("Station identifier", text: $identifier).textInputAutocapitalization(.never)
        TextField("Datum code", text: $datum).textInputAutocapitalization(.characters)
        Picker("Units", selection: $units) {
          Text("Metric").tag(TidesUnits.metric)
          Text("English").tag(TidesUnits.english)
        }
        Button("Load latest reading") { Task { await load() } }
      }.disabled(isLoading)
      if isLoading { ProgressView() }
      if let message { Text(message) }
      if let result {
        Section("Latest response") {
          Text("Reported station: " + result.metadata.identifier)
          if let observation = result.observation {
            Text(observation.time.rawValue + " GMT")
            Text(
              observation.height.value == nil
                ? "Missing height"
                : observation.height.rawValue
                  + (result.requestedQuery.units == .metric ? " m above " : " ft above ")
                  + result.requestedQuery.datum.rawValue)
            Text("Quality: " + observation.quality.rawValue + "; flags: " + observation.flags)
              .font(.caption)
          } else {
            Text("The successful response contains no reading.")
          }
        }
      }
      Text(
        "NOAA checks an eighteen-minute availability window. Each button press makes one request; a reading may be unavailable."
      )
      .font(.footnote)
    }
    .navigationTitle("Latest water level")
    .onChange(of: datum) { clear() }
    .onChange(of: identifier) { clear() }
    .onChange(of: units) { clear() }
  }

  private func clear() { message = nil; result = nil }

  private func load() async {
    isLoading = true; clear()
    defer { isLoading = false }
    do {
      let query = try LatestWaterLevelQuery(
        datum: TideDatum(rawValue: datum),
        stationIdentifier: CoastalStationIdentifier(identifier), units: units)
      result = try await TidesClient().latestWaterLevel(matching: query)
    } catch let error as TidesError {
      switch error {
      case .invalidLatestWaterLevelResponse:
        message = "NOAA returned multiple readings for the latest selector."
      case .provider(let refusal): message = refusal.message
      case .transport(.cancelled): break
      default: message = "Could not retrieve the latest reading."
      }
    } catch { message = "Choose a valid station, datum and units." }
  }
}
