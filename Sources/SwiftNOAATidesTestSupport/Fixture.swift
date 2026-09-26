import Foundation

package enum Fixture: String, CaseIterable, Sendable {
  /// Data API invalid-station refusal; exact request is recorded in Fixtures/manifest.json.
  case invalidStation = "invalid-station"
  /// /mdapi/prod/webapi/stations/9414290.json
  case station
  /// /mdapi/prod/webapi/stations/9414290/datums.json?units=metric
  case stationDatums = "station-datums"
  /// /mdapi/prod/webapi/stations/9414290/datums.json?units=english
  case stationDatumsEnglish = "station-datums-english"
  /// /mdapi/prod/webapi/stations/invalid.json
  case stationInvalidMDAPI = "station-invalid-mdapi"
  /// /mdapi/prod/webapi/stations/8557863.json
  case stationSubordinate = "station-subordinate"
  /// /mdapi/prod/webapi/stations.json?type=tidepredictions
  case stationsTidePredictions = "stations-tidepredictions"
  /// /mdapi/prod/webapi/stations.json?type=waterlevels
  case stationsWaterLevels = "stations-waterlevels"
  /// /api/prod/datagetter?begin_date=20260926+00%3A18&end_date=20260926+00%3A19&station=9414290&product=predictions&datum=MLLW&time_zone=gmt&units=metric&application=swift-noaa&format=json&interval=hilo
  case tideEmptyWindow = "tide-empty-window"
  /// /api/prod/datagetter?begin_date=20240926&end_date=20240926&station=9414290&product=predictions&datum=MLLW&time_zone=gmt&units=english&application=swift-noaa&format=json&interval=hilo
  case tideEnglish = "tide-english"
  /// /api/prod/datagetter?begin_date=20260926&end_date=20260927&station=9414290&product=predictions&datum=MLLW&time_zone=gmt&interval=hilo&units=metric&application=swift-noaa&format=json
  case tideHighLow = "tide-high-low"
  /// /api/prod/datagetter?begin_date=20260926&end_date=20260926&station=9414290&product=predictions&datum=MLLW&time_zone=gmt&interval=h&units=metric&application=swift-noaa&format=json
  case tideHourly = "tide-hourly"
  /// /api/prod/datagetter?begin_date=20240926+00%3A00&end_date=20240926+01%3A00&station=9414290&product=predictions&datum=MLLW&time_zone=gmt&units=metric&application=swift-noaa&format=json&interval=6
  case tideInclusive = "tide-inclusive"
  /// /api/prod/datagetter?begin_date=20240926+00%3A00&end_date=20240926+01%3A00&station=9414290&product=predictions&datum=INVALID&time_zone=gmt&units=metric&application=swift-noaa&format=json&interval=hilo
  case tideInvalidDatum = "tide-invalid-datum"
  /// /api/prod/datagetter?begin_date=20240926+00%3A00&end_date=20240926+01%3A00&station=9063020&product=predictions&datum=MLLW&time_zone=gmt&units=metric&application=swift-noaa&format=json&interval=hilo
  case tideNoData = "tide-no-data"
  /// /api/prod/datagetter?begin_date=20240926+00%3A00&end_date=20240925&station=9414290&product=predictions&datum=MLLW&time_zone=gmt&units=metric&application=swift-noaa&format=json&interval=hilo
  case tideReversed = "tide-reversed"
  /// /api/prod/datagetter?begin_date=20260926&end_date=20260927&station=8557863&product=predictions&datum=MLLW&time_zone=gmt&interval=hilo&units=metric&application=swift-noaa&format=json
  case tideSubordinate = "tide-subordinate"
  /// /api/prod/datagetter?begin_date=20240926+00%3A00&end_date=20240926+01%3A00&station=8557863&product=predictions&datum=MLLW&time_zone=gmt&units=metric&application=swift-noaa&format=json&interval=6
  case tideSubordinateSampled = "tide-subordinate-sampled"

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
