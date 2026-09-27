import Foundation
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Latest water level query", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct LatestWaterLevelQueryTests {
  @Test("Explicit context is retained without a range")
  func explicitContextIsRetainedWithoutARange() throws {
    let station = try CoastalStationIdentifier("9414290")
    let query = try LatestWaterLevelQuery(
      datum: TideDatum(rawValue: "future datum"), stationIdentifier: station,
      units: TidesUnits(rawValue: "future units"))
    #expect(query.datum.rawValue == "future datum")
    #expect(query.stationIdentifier == station)
    #expect(query.units.rawValue == "future units")
    #expect(
      TidesEndpoint.latestWaterLevel(matching: query).path
        == "/api/prod/datagetter?date=latest&datum=future%20datum&format=json&product=water_level&station=9414290&time_zone=gmt&units=future%20units"
    )
  }

  @Test("Invalid open codes fail at construction")
  func invalidOpenCodesFailAtConstruction() throws {
    let station = try CoastalStationIdentifier("9414290")
    for code in ["", "\n", "bad\u{7F}"] {
      #expect(throws: TidesQueryError.invalidDatum(code)) {
        try LatestWaterLevelQuery(
          datum: TideDatum(rawValue: code), stationIdentifier: station, units: .metric)
      }
      #expect(throws: TidesQueryError.invalidUnits(code)) {
        try LatestWaterLevelQuery(
          datum: .meanLowerLowWater, stationIdentifier: station, units: TidesUnits(rawValue: code))
      }
    }
  }

  @Test(
    "Recorded latest wire responses retain literal measurements",
    arguments: [Fixture.latestMetric, .latestEnglish])
  func recordedLatestWireResponsesRetainLiteralMeasurements(fixture: Fixture) throws {
    let result = try JSONDecoder().decode(WaterLevelResponse.self, from: fixture.data())
    #expect(result.observations.count == 1)
    let sample = try #require(result.observations.first)
    #expect(sample.height.rawValue == (fixture == .latestMetric ? "0.861" : "2.826"))
    #expect(sample.sigma.rawValue == (fixture == .latestMetric ? "0.043" : "0.141"))
    #expect(sample.time.rawValue == "2026-09-27 14:54")
    #expect(sample.quality.rawValue == "p")
    #expect(sample.flags == "0,0,0,0")
  }
}
