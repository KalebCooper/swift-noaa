import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Forecast code values", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ForecastCodeValueTests {
  @Test("Consumer enums create forecast options and endpoints")
  func consumerEnumsCreateForecastOptionsAndEndpoints() {
    let options = ForecastOptions(
      featureFlags: [ConsumerFeatureFlag.temperatureQuantity], units: ConsumerForecastUnits.metric)
    let endpoint = Endpoint<String>(
      featureFlags: [ConsumerFeatureFlag.temperatureQuantity], path: "/custom")

    #expect(options.featureFlags == [.temperatureQuantity])
    #expect(options.units == .si)
    #expect(endpoint.featureFlags == [.temperatureQuantity])
  }

  @Test("Unknown forecast codes survive a coding round trip")
  func unknownForecastCodesSurviveACodingRoundTrip() throws {
    let value = ForecastWindDirection(rawValue: "future-direction")
    let encoded = try JSONEncoder().encode(value)

    #expect(try JSONDecoder().decode(ForecastWindDirection.self, from: encoded) == value)
  }
}

private enum ConsumerFeatureFlag: String, Hashable {
  case temperatureQuantity = "forecast_temperature_qv"
}

private enum ConsumerForecastUnits: String {
  case metric = "si"
}
