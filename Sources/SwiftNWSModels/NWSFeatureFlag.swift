/// An extensible NWS Feature-Flags header value.
///
/// Known values match the live forecast schema. Consumer-defined values remain available in
/// ``rawValue`` for service additions the package does not know yet.
public struct NWSFeatureFlag: Hashable, RawRepresentable, Sendable {
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
