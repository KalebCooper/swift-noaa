import Foundation
import SwiftNOAATides
import SwiftNOAATidesModels
import SwiftUI

struct ObservedHighLowWaterLevelView: View {
  @State private var datum = "MLLW"
  @State private var day = Date.now
  @State private var identifier = "9414290"
  @State private var isLoading = false
  @State private var message: String?
  @State private var result: ObservedHighLowWaterLevels?
  @State private var units = TidesUnits.metric

  var body: some View {
    List {
      Section("Observed high/low request") {
        TextField("Station identifier", text: $identifier).textInputAutocapitalization(.never)
        TextField("Datum code", text: $datum).textInputAutocapitalization(.characters)
        DatePicker("Day (GMT)", selection: $day, displayedComponents: .date).environment(
          \.timeZone, .gmt)
        Picker("Units", selection: $units) {
          Text("Metric").tag(TidesUnits.metric)
          Text("English").tag(TidesUnits.english)
        }
        Button("Load observed high/low levels") { Task { await load() } }
      }.disabled(isLoading)
      if isLoading { ProgressView() }
      if let message { Text(message) }
      if let result {
        Section("Verified observed high/low levels") {
          if result.observations.isEmpty { Text("No observations in this successful response.") }
          ForEach(Array(result.observations.enumerated()), id: \.offset) { _, sample in
            VStack(alignment: .leading) {
              Text(sample.time.rawValue + " GMT; code: " + sample.kind.rawValue)
              Text(
                sample.height.rawValue
                  + (result.requestedQuery.units == .metric ? " m above " : " ft above ")
                  + result.requestedQuery.datum.rawValue)
              Text("Flags (inferred, level limit): " + sample.flags).font(.caption)
            }
          }
        }
      }
      Text(
        "These are provider-verified observed extrema. Verification availability is controlled by NOAA; no event is calculated from samples."
      )
      .font(.footnote)
    }
    .navigationTitle("Observed high/low water levels")
    .onChange(of: datum) { clear() }
    .onChange(of: day) { clear() }
    .onChange(of: identifier) { clear() }
    .onChange(of: units) { clear() }
  }

  private func clear() { message = nil; result = nil }

  private func load() async {
    isLoading = true; clear()
    defer { isLoading = false }
    do {
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = .gmt
      let begin = calendar.startOfDay(for: day)
      guard let end = calendar.date(byAdding: .day, value: 1, to: begin) else { return }
      let query = try ObservedHighLowWaterLevelQuery(
        datum: TideDatum(rawValue: datum),
        range: TidesDateRange(begin: begin, end: end.addingTimeInterval(-60)),
        stationIdentifier: CoastalStationIdentifier(identifier), units: units)
      result = try await TidesClient().observedHighLowWaterLevels(matching: query)
    } catch let error as TidesError {
      switch error {
      case .provider(let refusal): message = refusal.message
      case .transport(.cancelled): break
      default: message = "Could not retrieve observed high/low levels."
      }
    } catch { message = "Choose a valid station, datum and GMT day." }
  }
}
