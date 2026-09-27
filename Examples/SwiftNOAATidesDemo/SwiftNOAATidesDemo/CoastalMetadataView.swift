import SwiftNOAATides
import SwiftNOAATidesModels
import SwiftUI

struct CoastalMetadataView: View {
  @State private var identifier = "9414290"
  @State private var isLoading = false
  @State private var message: String?
  @State private var notices: CoastalNotices?
  @State private var sensors: CoastalSensors?

  var body: some View {
    List {
      Section("Station") {
        TextField("Station identifier", text: $identifier)
          .textInputAutocapitalization(.never)
        Button("Load notices") { Task { await loadNotices() } }
        Button("Load sensors") { Task { await loadSensors() } }
      }.disabled(isLoading)
      if isLoading { ProgressView() }
      if let message { Text(message) }
      if let notices {
        Section("Station notices") {
          if notices.notices.isEmpty { Text("No notices in this response.") }
          ForEach(Array(notices.notices.enumerated()), id: \.offset) { _, notice in
            VStack(alignment: .leading) {
              Text(verbatim: notice.name).font(.headline)
              Text(verbatim: notice.text)
            }
          }
        }
      }
      if let sensors {
        Section("Sensor status") {
          Text(
            "Enabled sensors do not guarantee a recent reading. Elevations use each sensor's reference."
          )
          if let values = sensors.sensors {
            if values.isEmpty { Text("No sensors in this response.") }
            ForEach(Array(values.enumerated()), id: \.offset) { _, sensor in
              VStack(alignment: .leading) {
                Text(sensor.name + " (" + sensor.identifier + ")").font(.headline)
                Text("Status: " + String(sensor.status.rawValue))
                if let elevation = sensor.elevation {
                  Text(
                    "Elevation: " + String(elevation) + " " + (sensors.units ?? "unspecified units")
                      + "; reference: " + (sensor.referenceDatum ?? "unspecified"))
                }
                if let message = sensor.message, !message.isEmpty { Text(verbatim: message) }
              }
            }
          } else {
            Text("NOAA returned no sensor table.")
          }
        }
      }
    }
    .navigationTitle("Station metadata")
    .onChange(of: identifier) {
      message = nil; notices = nil; sensors = nil
    }
  }

  private func loadNotices() async {
    isLoading = true; message = nil; notices = nil
    defer { isLoading = false }
    do {
      notices = try await TidesClient().notices(
        stationIdentifier: CoastalStationIdentifier(identifier))
    } catch { show(error) }
  }

  private func loadSensors() async {
    isLoading = true; message = nil; sensors = nil
    defer { isLoading = false }
    do {
      sensors = try await TidesClient().sensors(
        stationIdentifier: CoastalStationIdentifier(identifier), units: .metric)
    } catch { show(error) }
  }

  private func show(_ error: any Error) {
    if let error = error as? TidesError {
      switch error {
      case .provider(let refusal): message = refusal.message
      case .transport(.cancelled): break
      default: message = "Could not retrieve station metadata."
      }
    } else {
      message = "Enter a valid station identifier."
    }
  }
}
