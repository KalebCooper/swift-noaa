import Foundation

package enum Fixture: String, CaseIterable, Sendable {
  /// Data API invalid-station refusal; exact request is recorded in Fixtures/manifest.json.
  case invalidStation = "invalid-station"
  /// /mdapi/prod/webapi/stations/9414290.json
  case station
  /// /mdapi/prod/webapi/stations/invalid.json
  case stationInvalidMDAPI = "station-invalid-mdapi"
  /// /mdapi/prod/webapi/stations/8557863.json
  case stationSubordinate = "station-subordinate"
  /// /mdapi/prod/webapi/stations.json?type=tidepredictions
  case stationsTidePredictions = "stations-tidepredictions"
  /// /mdapi/prod/webapi/stations.json?type=waterlevels
  case stationsWaterLevels = "stations-waterlevels"

  package func data() throws -> Data {
    guard
      let url = Bundle.module.url(
        forResource: rawValue, withExtension: "json", subdirectory: "Fixtures")
    else {
      throw CocoaError(.fileNoSuchFile)
    }
    return try Data(contentsOf: url)
  }
}

package let suiteTimeLimitMinutes = 1
