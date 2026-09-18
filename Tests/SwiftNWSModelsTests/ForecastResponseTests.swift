import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Forecast responses", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ForecastResponseTests {
  @Test(
    "Forecast fixtures retain both representations",
    arguments: [
      Fixture.forecast, .forecastQuantities, .hourlyForecast, .hourlyForecastQuantities,
    ])
  func forecastFixturesRetainBothRepresentations(fixture: Fixture) throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let forecast = try decoder.decode(Feature<WeatherForecast>.self, from: fixture.data())
      .properties
    let first = try #require(forecast.periods.first)
    #expect(forecast.elevation == QuantitativeValue(unitCode: "wmoUnit:m", value: 155.1432))
    #expect(forecast.validTimes.rawValue == "2026-09-13T16:00:00+00:00/P7DT9H")
    // 2026-09-13T16:00:00+00:00, lasting seven days and nine hours.
    #expect(forecast.validTimes.start == Date(timeIntervalSince1970: 1_789_315_200))
    #expect(forecast.validTimes.duration.days == 7)
    #expect(forecast.validTimes.duration.hours == 9)
    #expect(first.endTime > first.startTime)
    #expect(first.temperatureTrend == nil)
    #expect(first.windDirection == .sse)
    switch fixture {
    case .forecast:
      #expect(forecast.units == .us)
      #expect(first.temperature == .value(101))
      #expect(first.temperatureUnit == .fahrenheit)
      #expect(first.windSpeed == .text("15 mph"))
      #expect(first.windGust == nil)
    case .forecastQuantities:
      #expect(forecast.units == .si)
      #expect(first.temperatureUnit == nil)
      #expect(
        first.temperature == .quantity(.init(unitCode: "wmoUnit:degC", value: 26.11111111111111)))
      #expect(
        first.windSpeed
          == .quantity(
            .init(maxValue: 16.09344, minValue: 8.04672, unitCode: "wmoUnit:km_h-1", value: nil)))
    case .hourlyForecast:
      #expect(forecast.periods.count == 156)
      #expect(forecast.units == .us)
      #expect(first.temperatureUnit == .fahrenheit)
      #expect(first.temperature == .value(97))
      #expect(first.relativeHumidity?.value == 43)
    case .hourlyForecastQuantities:
      #expect(forecast.periods.count == 156)
      #expect(forecast.units == .si)
      #expect(first.temperatureUnit == nil)
      #expect(first.windGust == .quantity(.init(unitCode: "wmoUnit:km_h-1", value: 32.18688)))
      #expect(first.dewpoint?.value == 21.666666666666668)
    default: Issue.record("Unexpected fixture")
    }
    let encoded = try JSONEncoder().encode(forecast)
    #expect(try decoder.decode(WeatherForecast.self, from: encoded) == forecast)
  }

  @Test("Forecast links preserve queries and replace units")
  func forecastLinksPreserveQueriesAndReplaceUnits() throws {
    var point = try JSONDecoder().decode(Feature<Point>.self, from: Fixture.point.data()).properties
    point.forecast = try #require(
      URL(string: "https://API.WEATHER.GOV:443/gridpoints/NEW/1,2/forecast?x=a%2Fb&units=us"))
    let endpoint = try #require(
      Endpoint.forecast(
        for: point,
        options: .init(featureFlags: [.windSpeedQuantity, .temperatureQuantity], units: .si)))
    #expect(endpoint.path == "/gridpoints/NEW/1,2/forecast?x=a%2Fb&units=si")
    #expect(endpoint.featureFlags == [.temperatureQuantity, .windSpeedQuantity])
    point.forecast = try #require(URL(string: "http://api.weather.gov/forecast"))
    #expect(Endpoint.forecast(for: point) == nil)
  }

  @Test("Forecast timestamps retain milliseconds when encoded")
  func forecastTimestampsRetainMillisecondsWhenEncoded() throws {
    var forecast = try JSONDecoder().decode(
      Feature<WeatherForecast>.self, from: Fixture.forecast.data()
    ).properties
    let instant = try Date(
      "2026-09-13T14:30:00.125Z",
      strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    forecast.generatedAt = instant
    forecast.periods[0].startTime = instant
    let decoded = try JSONDecoder().decode(
      WeatherForecast.self, from: JSONEncoder().encode(forecast))
    #expect(decoded.generatedAt == instant)
    #expect(decoded.periods[0].startTime == instant)
  }

  @Test("Malformed forecast values fail decoding")
  func malformedForecastValuesFailDecoding() throws {
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(ForecastTemperature.self, from: Data(#""hot""#.utf8))
    }
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(ForecastWind.self, from: Data("15".utf8))
    }
  }

  @Test("Unknown forecast codes and null quantities survive")
  func unknownForecastCodesAndNullQuantitiesSurvive() throws {
    var object = try #require(
      JSONSerialization.jsonObject(with: Fixture.hourlyForecastQuantities.data()) as? [String: Any])
    var properties = try #require(object["properties"] as? [String: Any])
    var periods = try #require(properties["periods"] as? [[String: Any]])
    periods[0]["name"] = nil
    periods[0]["temperature"] = ["unitCode": "future:unit", "value": NSNull()]
    periods[0]["temperatureTrend"] = "future-trend"
    periods[0]["temperatureUnit"] = "future-temperature-unit"
    periods[0]["windDirection"] = "future-direction"
    periods[0]["startTime"] = "2026-09-13T23:00:00.123Z"
    properties["periods"] = periods
    properties["units"] = "future-units"
    object["properties"] = properties
    let body = try JSONSerialization.data(withJSONObject: object)
    let first = try #require(
      JSONDecoder().decode(Feature<WeatherForecast>.self, from: body).properties.periods.first)
    #expect(first.name == nil)
    #expect(first.temperature == .quantity(.init(unitCode: "future:unit", value: nil)))
    #expect(first.temperatureTrend?.rawValue == "future-trend")
    #expect(first.temperatureUnit?.rawValue == "future-temperature-unit")
    #expect(first.windDirection.rawValue == "future-direction")
    #expect(
      try JSONDecoder().decode(Feature<WeatherForecast>.self, from: body).properties.units.rawValue
        == "future-units")
  }
}
