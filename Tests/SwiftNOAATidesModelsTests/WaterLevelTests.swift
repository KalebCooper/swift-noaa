import Foundation
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Measured water-level models", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct WaterLevelTests {
  @Test("Calendar months clamp month-end without fixed day durations")
  func calendarMonthsClampMonthEndWithoutFixedDayDurations() throws {
    let start = try TidesTimestamp("2024-01-31 00:00").date
    let end = try TidesTimestamp("2024-02-29 00:00").date
    let station = try CoastalStationIdentifier("9414290")
    enum Datum: String { case chart = "MLLW" }
    let query = try WaterLevelQuery(
      datum: TideDatum(Datum.chart),
      range: TidesDateRange(begin: start, end: end), stationIdentifier: station, units: .metric)
    let request = TidesRequest.waterLevels(matching: query)
    let _: TidesRequest<WaterLevels> = request
    #expect(request.resolution == .waterLevels(query))
    #expect(Set([request, request]).count == 1)
    #expect(
      TidesEndpoint.waterLevels(matching: query).path
        == "/api/prod/datagetter?begin_date=20240131%2000:00&datum=MLLW&end_date=20240229%2000:00&format=json&product=water_level&station=9414290&time_zone=gmt&units=metric"
    )
    #expect(throws: TidesQueryError.rangeTooLong(maximumMonths: 1)) {
      try WaterLevelQuery(
        datum: .meanLowerLowWater,
        range: TidesDateRange(begin: start, end: end.addingTimeInterval(60)),
        stationIdentifier: station, units: .metric)
    }
  }

  @Test("Malformed measurements do not become missing values")
  func malformedMeasurementsDoNotBecomeMissingValues() throws {
    for text in ["NaN", "null", " ", "--1", "01", "1e999"] {
      #expect(throws: TidesQueryError.invalidNumber(text)) { try TidesMeasurementValue(text) }
    }
    for body in ["{}", #"{"data":[],"metadata":null}"#, #"{"data":null}"#, #"{"predictions":[]}"#] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(WaterLevelResponse.self, from: Data(body.utf8))
      }
    }
    for body in [
      #"{"t":"2024-01-01 00:00","v":null,"s":"","f":"0","q":"p"}"#,
      #"{"t":"2024-01-01 00:00","v":"1","s":"NaN","f":"0","q":"p"}"#,
      #"{"t":"2024-01-01 00:00","v":"1","s":"0","f":"0"}"#,
    ] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(WaterLevel.self, from: Data(body.utf8))
      }
    }
  }

  @Test("Missing sigma and omitted observations remain gaps")
  func missingSigmaAndOmittedObservationsRemainGaps() throws {
    let response = try JSONDecoder().decode(
      WaterLevelResponse.self, from: Fixture.waterMissingSigma.data())
    #expect(response.observations.count == 3)
    #expect(response.observations[1].height.value == 1.677)
    #expect(response.observations[1].sigma.rawValue == "")
    #expect(response.observations[1].sigma.value == nil)
    #expect(response.observations[1].flags == "1,0,0,0")
    let gap = try JSONDecoder().decode(WaterLevelResponse.self, from: Fixture.waterNaplesGap.data())
    #expect(gap.observations.count == 172)
    #expect(gap.observations.last?.time.rawValue == "2022-09-28 17:06")
    #expect(try TidesMeasurementValue("0").value == 0)
    let unknown = try JSONDecoder().decode(
      WaterLevel.self,
      from: Data(
        #"{"t":"2024-01-01 00:00","v":"","s":"-0.010","f":"future,flags","q":"future"}"#.utf8))
    #expect(unknown.height.rawValue == "")
    #expect(unknown.height.value == nil)
    #expect(unknown.sigma.value == -0.01)
    #expect(unknown.quality.rawValue == "future")
    #expect(unknown.flags == "future,flags")
    #expect(
      try JSONDecoder().decode(WaterLevel.self, from: JSONEncoder().encode(unknown)) == unknown)
  }

  @Test("Recorded measurements retain provider quality metadata and inclusive bounds")
  func recordedMeasurementsRetainProviderQualityMetadataAndInclusiveBounds() throws {
    let value = try JSONDecoder().decode(WaterLevelResponse.self, from: Fixture.waterLevel.data())
    #expect(value.metadata.identifier == "9414290")
    #expect(value.metadata.latitude.rawValue == "37.8063")
    #expect(value.metadata.longitude.value == -122.4659)
    #expect(value.observations.count == 11)
    #expect(value.observations.first?.height.value == 1.647)
    #expect(value.observations.first?.sigma.value == 0.051)
    #expect(value.observations.first?.quality == .verified)
    #expect(value.observations.last?.time.rawValue == "2024-09-26 01:00")
    let preliminary = try JSONDecoder().decode(
      WaterLevelResponse.self, from: Fixture.waterPreliminary.data())
    #expect(preliminary.observations.first?.quality == .preliminary)
    #expect(preliminary.observations.first?.height.value == 0.543)
    #expect(preliminary.observations.first?.flags == "1,0,0,0")
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(TidePredictionResponse.self, from: Fixture.waterLevel.data())
    }
    let empty = try JSONDecoder().decode(
      WaterLevelResponse.self,
      from: Data(#"{"metadata":{"id":"x","name":"","lat":"0","lon":"0"},"data":[]}"#.utf8))
    #expect(empty.observations.isEmpty)
  }
}
