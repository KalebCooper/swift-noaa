/// An extensible code for the intensity of forecast weather, such as `light` or `heavy`.
///
/// Named values match the live NWS schema. Unknown service values remain available in ``rawValue``.
///
/// ```swift
/// if weather.intensity == .veryLight { print("Very light") }
/// ```
public struct ForecastWeatherIntensity: Codable, Hashable, RawRepresentable, Sendable {
  /// Heavy.
  public static let heavy = Self(rawValue: "heavy")

  /// Light.
  public static let light = Self(rawValue: "light")

  /// Moderate.
  public static let moderate = Self(rawValue: "moderate")

  /// Very light.
  public static let veryLight = Self(rawValue: "very_light")

  /// The service's exact code.
  public let rawValue: String

  /// Creates a code from a consumer-defined String-backed value.
  /// - Parameter value: The value whose raw string to retain.
  public init<Value>(_ value: Value) where Value: RawRepresentable, Value.RawValue == String {
    self.init(rawValue: value.rawValue)
  }

  /// Creates a code without restricting future service values.
  /// - Parameter rawValue: The exact code.
  public init(rawValue: String) { self.rawValue = rawValue }

  /// Decodes the exact service code.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError` for a non-string value.
  public init(from decoder: any Decoder) throws {
    rawValue = try decoder.singleValueContainer().decode(String.self)
  }

  /// Encodes the exact service code.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
