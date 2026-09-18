/// An extensible intensity for a reported weather phenomenon.
///
/// Known values match the live NWS schema. Unknown service values remain available in ``rawValue``.
///
/// ```swift
/// if phenomenon.intensity == .heavy {
///   print("Heavy \(phenomenon.weather.rawValue)")
/// }
/// ```
public struct WeatherPhenomenonIntensity: Codable, Hashable, RawRepresentable, Sendable {
  /// Heavy, the METAR `+` prefix.
  public static let heavy = Self(rawValue: "heavy")

  /// Light, the METAR `-` prefix.
  public static let light = Self(rawValue: "light")

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
