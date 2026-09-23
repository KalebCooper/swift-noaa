/// An extensible value for the forecast routes' Feature-Flags header.
///
/// The specification declares the header on the forecast and hourly forecast routes only, and other
/// routes ignore it. The statics match the two values the specification lists. A quantity flag
/// answers its field as a ``QuantitativeValue`` in WMO SI units whatever ``ForecastOptions/units``
/// says; the units option still governs every unflagged field. The service ignores a flag it does
/// not know rather than rejecting the request, and it retires flags after an announced adoption
/// window, when the flagged shape becomes the default. Consumer-defined values remain available in
/// ``rawValue`` for service additions the package does not know yet.
///
/// ```swift
/// let options = ForecastOptions(featureFlags: [.temperatureQuantity])
/// ```
public struct ForecastFeatureFlag: Hashable, RawRepresentable, Sendable {
  /// Requests forecast temperatures as quantitative values.
  public static let temperatureQuantity = Self(rawValue: "forecast_temperature_qv")

  /// Requests forecast wind speeds and gusts as quantitative values.
  public static let windSpeedQuantity = Self(rawValue: "forecast_wind_speed_qv")

  /// The exact header value.
  public let rawValue: String

  /// Creates a flag from a consumer-defined String-backed value.
  /// - Parameter value: The value whose raw string to retain.
  public init<Value>(_ value: Value) where Value: RawRepresentable, Value.RawValue == String {
    self.init(rawValue: value.rawValue)
  }

  /// Creates a flag without restricting future service values.
  /// - Parameter rawValue: The exact header value.
  public init(rawValue: String) { self.rawValue = rawValue }
}
