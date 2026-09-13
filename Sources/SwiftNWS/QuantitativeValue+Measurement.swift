import Foundation
import SwiftNWSModels

extension QuantitativeValue {
  /// The reported percentage as a fraction suitable for percentage formatting.
  ///
  /// For example, a value of 65 with `wmoUnit:percent` yields 0.65. Returns nil for
  /// other units or a missing value. Values are not clamped to zero through one.
  public var fraction: Double? {
    guard unitCode == "wmoUnit:percent" else { return nil }
    return value.map { $0 / 100 }
  }

  /// Converts the reported value to a Foundation measurement in the requested unit.
  ///
  /// Maps the temperature, speed, pressure, length, and angle codes in the recorded
  /// NWS responses. Foundation performs the conversion and supplies formatting on platforms
  /// that support measurement format styles. Percentages use ``fraction``.
  /// Unknown codes, incompatible dimensions, and missing values return nil.
  /// Range bounds and quality flags remain available on the original quantity.
  ///
  /// ```swift
  /// let temperature = observation.temperature?.measurement(in: UnitTemperature.fahrenheit)
  /// ```
  ///
  /// - Parameter unit: The destination unit, such as `UnitSpeed.milesPerHour`.
  /// - Returns: The converted measurement, or nil when conversion is unavailable.
  public func measurement<UnitType: Dimension>(in unit: UnitType) -> Measurement<UnitType>? {
    guard let value, let source = foundationUnit as? UnitType else { return nil }
    return Measurement(value: value, unit: source).converted(to: unit)
  }

  private var foundationUnit: Dimension? {
    switch unitCode {
    case "wmoUnit:degC": UnitTemperature.celsius
    case "wmoUnit:degF": UnitTemperature.fahrenheit
    case "wmoUnit:degree_(angle)": UnitAngle.degrees
    case "wmoUnit:K": UnitTemperature.kelvin
    case "wmoUnit:km_h-1": UnitSpeed.kilometersPerHour
    case "wmoUnit:m": UnitLength.meters
    case "wmoUnit:mm": UnitLength.millimeters
    case "wmoUnit:Pa": UnitPressure.newtonsPerMetersSquared
    default: nil
    }
  }
}
