import Foundation
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Verified hourly-height models", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct HourlyWaterLevelTests {
  @Test("Hourly queries use the separate product and calendar-year bounds")
  func hourlyQueriesUseTheSeparateProductAndCalendarYearBounds() throws {
    let begin = try TidesTimestamp("2024-02-29 00:00").date
    let end = try TidesTimestamp("2025-02-28 00:00").date
    let station = try CoastalStationIdentifier("9414290")
    let query = try HourlyWaterLevelQuery(
      datum: .meanLowerLowWater,
      range: TidesDateRange(begin: begin, end: end), stationIdentifier: station, units: .metric)
    let request = TidesRequest.hourlyWaterLevels(matching: query)
    let _: TidesRequest<HourlyWaterLevels> = request
    #expect(request.resolution == .hourlyWaterLevels(query))
    #expect(
      TidesEndpoint.hourlyWaterLevels(matching: query).path
        == "/api/prod/datagetter?begin_date=20240229%2000:00&datum=MLLW&end_date=20250228%2000:00&format=json&product=hourly_height&station=9414290&time_zone=gmt&units=metric"
    )
    #expect(throws: TidesQueryError.rangeTooLong(maximumMonths: 12)) {
      try HourlyWaterLevelQuery(
        datum: .meanLowerLowWater,
        range: TidesDateRange(begin: begin, end: end.addingTimeInterval(60)),
        stationIdentifier: station, units: .metric)
    }
  }

  @Test("Hourly required fields and envelopes fail strictly")
  func hourlyRequiredFieldsAndEnvelopesFailStrictly() throws {
    for body in ["{}", #"{"data":[],"metadata":null}"#, #"{"predictions":[]}"#] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(HourlyWaterLevelResponse.self, from: Data(body.utf8))
      }
    }
    for body in [
      #"{"t":"2024-01-01 00:00","v":"1","s":"0"}"#,
      #"{"t":"2024-01-01 00:00","v":"NaN","s":"0","f":"0,0"}"#,
      #"{"t":"2024-01-01 00:00","v":"1","s":null,"f":"0,0"}"#,
    ] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(HourlyWaterLevel.self, from: Data(body.utf8))
      }
    }
  }

  @Test("Hourly unknown flags and missing text remain observable")
  func hourlyUnknownFlagsAndMissingTextRemainObservable() throws {
    let value = try JSONDecoder().decode(
      HourlyWaterLevel.self,
      from: Data(#"{"t":"2024-01-01 00:00","v":"","s":"","f":"future,1,extra"}"#.utf8))
    #expect(value.height.value == nil)
    #expect(value.sigma.rawValue == "")
    #expect(value.flags == "future,1,extra")
    #expect(
      try JSONDecoder().decode(HourlyWaterLevel.self, from: JSONEncoder().encode(value)) == value)
    let empty = try JSONDecoder().decode(
      HourlyWaterLevelResponse.self,
      from: Data(#"{"metadata":{"id":"x","name":"","lat":"0","lon":"0"},"data":[]}"#.utf8))
    #expect(empty.observations.isEmpty)
  }

  @Test("Recorded hourly heights retain two flags without inventing quality")
  func recordedHourlyHeightsRetainTwoFlagsWithoutInventingQuality() throws {
    let value = try JSONDecoder().decode(
      HourlyWaterLevelResponse.self, from: Fixture.hourlyWater.data())
    #expect(value.observations.count == 2)
    #expect(value.metadata.identifier == "9414290")
    #expect(value.observations.first?.height.value == 1.647)
    #expect(value.observations.first?.sigma.value == 0.051)
    #expect(value.observations.first?.flags == "0,0")
    #expect(value.observations.last?.height.value == 1.76)
    #expect(value.observations.last?.time.rawValue == "2024-09-26 01:00")
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(WaterLevelResponse.self, from: Fixture.hourlyWater.data())
    }
  }
}
