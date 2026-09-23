import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Zone forecasts", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ZoneForecastTests {
  // 2026-09-20T03:33:00-05:00, the recorded update instant.
  private let recordedUpdated = Date(timeIntervalSince1970: 1_789_893_180)

  @Test("The recorded zone forecast decodes its link, update instant, text periods, and polygon")
  func theRecordedZoneForecastDecodesItsLinkUpdateInstantTextPeriodsAndPolygon() throws {
    let feature = try JSONDecoder().decode(
      Feature<ZoneForecast>.self, from: Fixture.zoneForecast.data())
    let forecast = feature.properties

    #expect(forecast.zone == URL(string: "https://api.weather.gov/zones/forecast/TXZ192"))
    #expect(forecast.updated == recordedUpdated)
    #expect(forecast.periods.map(\.number) == [1, 2, 3, 4, 5, 6])
    #expect(
      forecast.periods.map(\.name) == [
        "Today", "Tonight", "Monday", "Monday Night", "Tuesday",
        "Tuesday Night through Saturday",
      ])
    #expect(
      forecast.periods.first?.detailedForecast
        == "Partly cloudy. Highs in the upper 90s. South winds around 5 mph.")
    #expect(forecast.periods.last?.detailedForecast.hasSuffix("readings up to 105.") == true)
    guard case .object(let geometry) = feature.geometry,
      case .array(let rings) = geometry["coordinates"], case .array(let points) = rings.first
    else {
      Issue.record("Expected a polygon geometry object")
      return
    }
    #expect(geometry["type"] == .string("Polygon"))
    #expect(points.count == 223)
    #expect(points.first == .array([.number(-97.371796), .number(30.417212)]))
  }

  @Test("Zone periods need no grid period fields and keep nonconsecutive numbers")
  func zonePeriodsNeedNoGridPeriodFieldsAndKeepNonconsecutiveNumbers() throws {
    let body = Data(
      """
      {"zone":"https://api.weather.gov/zones/forecast/TXZ192","updated":"2026-09-20T03:33:00-05:00",
      "periods":[{"number":7,"name":"Later","detailedForecast":"Hot."},
      {"number":3,"name":"Earlier","detailedForecast":"Hotter."}]}
      """.utf8)
    let forecast = try JSONDecoder().decode(ZoneForecast.self, from: body)
    #expect(forecast.periods.map(\.number) == [7, 3])
    #expect(forecast.periods.map(\.name) == ["Later", "Earlier"])
    #expect(forecast.updated == recordedUpdated)
  }

  @Test(
    "A missing period field, a missing forecast field, or a malformed update instant fails",
    arguments: [
      "{\"zone\":\"https://api.weather.gov/zones/forecast/TXZ192\",\"updated\":\"2026-09-20T03:33:00-05:00\",\"periods\":[{\"number\":1,\"name\":\"Today\"}]}",
      "{\"zone\":\"https://api.weather.gov/zones/forecast/TXZ192\",\"updated\":\"2026-09-20T03:33:00-05:00\"}",
      "{\"updated\":\"2026-09-20T03:33:00-05:00\",\"periods\":[]}",
      "{\"zone\":\"https://api.weather.gov/zones/forecast/TXZ192\",\"updated\":\"yesterday\",\"periods\":[]}",
    ])
  func aMissingPeriodFieldAMissingForecastFieldOrAMalformedUpdateInstantFails(body: String)
    throws
  {
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(ZoneForecast.self, from: Data(body.utf8))
    }
  }

  @Test("A zone forecast survives a Codable round trip independent of the coder's date strategy")
  func aZoneForecastSurvivesACodableRoundTripIndependentOfTheCodersDateStrategy() throws {
    let recorded = try JSONDecoder().decode(
      Feature<ZoneForecast>.self, from: Fixture.zoneForecast.data())
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .secondsSince1970
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .deferredToDate
    let encoded = try encoder.encode(recorded)
    let decoded = try decoder.decode(Feature<ZoneForecast>.self, from: encoded)
    #expect(decoded == recorded)
    #expect(decoded.geometry == recorded.geometry)
    let text = try #require(String(data: encoded, encoding: .utf8))
    #expect(text.contains("\"updated\":\"2026-09-20T08:33:00.000Z\""))
  }
}
