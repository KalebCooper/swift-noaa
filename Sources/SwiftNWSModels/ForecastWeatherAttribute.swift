/// An extensible code for an attribute of forecast weather, such as `heavy_rain` or `gusty_wind`.
///
/// Named values match the live NWS schema. Unknown service values remain available in ``rawValue``.
///
/// ```swift
/// if weather.attributes.contains(.heavyRain) { print("Heavy rain possible") }
/// ```
public struct ForecastWeatherAttribute: Codable, Hashable, RawRepresentable, Sendable {
  /// Damaging wind.
  public static let damagingWind = Self(rawValue: "damaging_wind")

  /// Dry thunderstorms.
  public static let dryThunderstorms = Self(rawValue: "dry_thunderstorms")

  /// Flooding.
  public static let flooding = Self(rawValue: "flooding")

  /// Gusty wind.
  public static let gustyWind = Self(rawValue: "gusty_wind")

  /// Heavy rain.
  public static let heavyRain = Self(rawValue: "heavy_rain")

  /// Large hail.
  public static let largeHail = Self(rawValue: "large_hail")

  /// Small hail.
  public static let smallHail = Self(rawValue: "small_hail")

  /// Tornadoes.
  public static let tornadoes = Self(rawValue: "tornadoes")

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
