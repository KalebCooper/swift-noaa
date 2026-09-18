/// An extensible METAR descriptor that qualifies a reported weather phenomenon.
///
/// Known values match the live NWS schema. Unknown service values remain available in ``rawValue``.
///
/// ```swift
/// if phenomenon.modifier == .freezing {
///   print("Freezing \(phenomenon.weather.rawValue)")
/// }
/// ```
public struct WeatherPhenomenonModifier: Codable, Hashable, RawRepresentable, Sendable {
  /// Raised by wind to two meters or more, `BL`.
  public static let blowing = Self(rawValue: "blowing")

  /// Freezing on contact, `FZ`.
  public static let freezing = Self(rawValue: "freezing")

  /// Raised by wind to less than two meters, `DR`.
  public static let lowDrifting = Self(rawValue: "low_drifting")

  /// Covering part of the station, `PR`.
  public static let partial = Self(rawValue: "partial")

  /// In patches, `BC`.
  public static let patches = Self(rawValue: "patches")

  /// Shallow, `MI`.
  public static let shallow = Self(rawValue: "shallow")

  /// Falling as showers, `SH`.
  public static let showers = Self(rawValue: "showers")

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
