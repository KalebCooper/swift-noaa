import Foundation

package enum Fixture: String, CaseIterable, Sendable {
  /// /api/prod/datagetter?begin_date=20240926+00%3A00&end_date=20240926+01%3A00&station=9414290&product=hourly_height&datum=INVALID&time_zone=gmt&units=metric&application=swift-noaa&format=json
  case hourlyInvalidDatum = "hourly-invalid-datum"
  /// /api/prod/datagetter?begin_date=18000101&end_date=18000101&station=9414290&product=hourly_height&datum=MLLW&time_zone=gmt&units=metric&application=swift-noaa&format=json
  case hourlyNoData = "hourly-no-data"
  /// /api/prod/datagetter?begin_date=20240229+00%3A00&end_date=20250302+00%3A00&station=9414290&product=hourly_height&datum=MLLW&time_zone=gmt&units=metric&application=swift-noaa&format=json
  case hourlyOverYear = "hourly-over-year"
  /// /api/prod/datagetter?begin_date=20240926+00%3A00&end_date=20240926+01%3A00&station=9414290&product=hourly_height&datum=MLLW&time_zone=gmt&units=metric&application=swift-noaa&format=json
  case hourlyWater = "hourly-water"
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

  /// /api/prod/datagetter?begin_date=20240926+00%3A00&end_date=20240926+01%3A00&station=9414290&product=water_level&datum=INVALID&time_zone=gmt&units=metric&application=swift-noaa&format=json
  case waterInvalidDatum = "water-invalid-datum"
  /// /api/prod/datagetter?begin_date=20240926%2000:00&end_date=20240926%2001:00&station=9414290&product=water_level&datum=MLLW&time_zone=gmt&units=metric&application=swift-noaa&format=json
  case waterLevel = "water-level"
  /// /api/prod/datagetter?begin_date=20260909+17%3A30&end_date=20260909+17%3A42&station=9414290&product=water_level&datum=MLLW&time_zone=gmt&units=metric&application=swift-noaa&format=json
  case waterMissingSigma = "water-missing-sigma"
  /// /api/prod/datagetter?begin_date=20220928+00%3A00&end_date=20220929+00%3A00&station=8725110&product=water_level&datum=MLLW&time_zone=gmt&units=metric&application=swift-noaa&format=json
  case waterNaplesGap = "water-naples-gap"
  /// /api/prod/datagetter?begin_date=18000101&end_date=18000101&station=9414290&product=water_level&datum=MLLW&time_zone=gmt&units=metric&application=swift-noaa&format=json
  case waterNoData = "water-no-data"
  /// /api/prod/datagetter?begin_date=20240131+00%3A00&end_date=20240303+00%3A00&station=9414290&product=water_level&datum=MLLW&time_zone=gmt&units=metric&application=swift-noaa&format=json
  case waterOverMonth = "water-over-month"
  /// /api/prod/datagetter?begin_date=20260926+00%3A00&end_date=20260926+01%3A00&station=9414290&product=water_level&datum=MLLW&time_zone=gmt&units=metric&application=swift-noaa&format=json
  case waterPreliminary = "water-preliminary"

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
