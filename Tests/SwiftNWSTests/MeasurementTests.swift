import Foundation
import SwiftNWS
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("WMO measurements", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct MeasurementTests {
  @Test("Every recorded WMO code has a conversion")
  func everyRecordedWMOCodeHasAConversion() throws {
    let supported: Set<String> = [
      "wmoUnit:Pa", "wmoUnit:degC", "wmoUnit:degree_(angle)",
      "wmoUnit:km_h-1", "wmoUnit:m", "wmoUnit:mm", "wmoUnit:percent",
    ]
    var found = Set<String>()
    func visit(_ value: Any) {
      if let object = value as? [String: Any] {
        if let code = object["unitCode"] as? String { found.insert(code) }
        for child in object.values { visit(child) }
      } else if let array = value as? [Any] {
        for child in array { visit(child) }
      }
    }
    for fixture in [
      Fixture.forecast, .forecastQuantities, .hourlyForecast, .hourlyForecastQuantities,
      .observation, .observationStations, .point,
    ] {
      visit(try JSONSerialization.jsonObject(with: fixture.data()))
    }
    #expect(found == supported)
    #expect(
      try #require(
        QuantitativeValue(unitCode: "wmoUnit:Pa", value: 101_325)
          .measurement(in: UnitPressure.hectopascals)
      ).value == 1013.25)
    #expect(
      try #require(
        QuantitativeValue(unitCode: "wmoUnit:degC", value: 0)
          .measurement(in: UnitTemperature.fahrenheit)
      ).value.isApproximately(32))
    #expect(
      try #require(
        QuantitativeValue(unitCode: "wmoUnit:degree_(angle)", value: 180)
          .measurement(in: UnitAngle.radians)
      ).value.isApproximately(.pi))
    #expect(
      try #require(
        QuantitativeValue(unitCode: "wmoUnit:km_h-1", value: 36)
          .measurement(in: UnitSpeed.metersPerSecond)
      ).value.isApproximately(10))
    #expect(
      try #require(
        QuantitativeValue(unitCode: "wmoUnit:m", value: 1609.344)
          .measurement(in: UnitLength.miles)
      ).value.isApproximately(1))
    #expect(
      try #require(
        QuantitativeValue(unitCode: "wmoUnit:mm", value: 25.4)
          .measurement(in: UnitLength.inches)
      ).value.isApproximately(1))
    #expect(QuantitativeValue(unitCode: "wmoUnit:percent", value: 65).fraction == 0.65)
  }

  @Test("Missing, unknown, and incompatible measurements remain unavailable")
  func missingUnknownAndIncompatibleMeasurementsRemainUnavailable() {
    #expect(
      QuantitativeValue(unitCode: "wmoUnit:degC", value: nil)
        .measurement(in: UnitTemperature.celsius) == nil)
    #expect(
      QuantitativeValue(unitCode: "wmoUnit:future", value: 12)
        .measurement(in: UnitTemperature.celsius) == nil)
    #expect(
      QuantitativeValue(unitCode: "wmoUnit:Pa", value: 12)
        .measurement(in: UnitTemperature.celsius) == nil)
    #expect(QuantitativeValue(unitCode: "wmoUnit:percent", value: nil).fraction == nil)
    #expect(QuantitativeValue(unitCode: "wmoUnit:degC", value: 12).fraction == nil)
    #expect(QuantitativeValue(unitCode: "wmoUnit:percent", value: 125).fraction == 1.25)
  }

  @Test("Temperature offsets convert below freezing", arguments: [-40.0, 0, 100])
  func temperatureOffsetsConvertBelowFreezing(celsius: Double) throws {
    let quantity = QuantitativeValue(unitCode: "wmoUnit:degC", value: celsius)
    let fahrenheit = try #require(quantity.measurement(in: UnitTemperature.fahrenheit))
    #expect(fahrenheit.value.isApproximately(celsius * 1.8 + 32))
    #expect(
      try #require(
        QuantitativeValue(unitCode: "wmoUnit:degF", value: fahrenheit.value)
          .measurement(in: UnitTemperature.celsius)
      ).value.isApproximately(celsius))
    #expect(
      try #require(
        QuantitativeValue(unitCode: "wmoUnit:K", value: celsius + 273.15)
          .measurement(in: UnitTemperature.celsius)
      ).value.isApproximately(celsius))
  }
}

extension Double {
  fileprivate func isApproximately(_ other: Double) -> Bool { abs(self - other) < 0.0001 }
}
