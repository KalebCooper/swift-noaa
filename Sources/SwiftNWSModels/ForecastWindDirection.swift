/// An extensible 16-point forecast wind-direction code.
///
/// Known values match the live NWS schema. Unknown service values remain available in ``rawValue``.
public struct ForecastWindDirection: Codable, Hashable, RawRepresentable, Sendable {
  /// East.
  public static let e = Self(rawValue: "E")
  /// East-northeast.
  public static let ene = Self(rawValue: "ENE")
  /// East-southeast.
  public static let ese = Self(rawValue: "ESE")
  /// North.
  public static let n = Self(rawValue: "N")
  /// Northeast.
  public static let ne = Self(rawValue: "NE")
  /// North-northeast.
  public static let nne = Self(rawValue: "NNE")
  /// North-northwest.
  public static let nnw = Self(rawValue: "NNW")
  /// Northwest.
  public static let nw = Self(rawValue: "NW")
  /// South.
  public static let s = Self(rawValue: "S")
  /// Southeast.
  public static let se = Self(rawValue: "SE")
  /// South-southeast.
  public static let sse = Self(rawValue: "SSE")
  /// South-southwest.
  public static let ssw = Self(rawValue: "SSW")
  /// Southwest.
  public static let sw = Self(rawValue: "SW")
  /// West.
  public static let w = Self(rawValue: "W")
  /// West-northwest.
  public static let wnw = Self(rawValue: "WNW")
  /// West-southwest.
  public static let wsw = Self(rawValue: "WSW")

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
