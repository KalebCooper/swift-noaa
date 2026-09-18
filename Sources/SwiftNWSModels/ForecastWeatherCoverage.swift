/// An extensible code for how much of an area, or how likely, forecast weather is, such as `scattered` or `slight_chance`.
///
/// Named values match the live NWS schema. Unknown service values remain available in ``rawValue``.
///
/// ```swift
/// if weather.coverage == .slightChance { print("Slight chance") }
/// ```
public struct ForecastWeatherCoverage: Codable, Hashable, RawRepresentable, Sendable {
  /// In areas.
  public static let areas = Self(rawValue: "areas")

  /// Brief.
  public static let brief = Self(rawValue: "brief")

  /// A chance.
  public static let chance = Self(rawValue: "chance")

  /// Definite.
  public static let definite = Self(rawValue: "definite")

  /// A few.
  public static let few = Self(rawValue: "few")

  /// Frequent.
  public static let frequent = Self(rawValue: "frequent")

  /// Intermittent.
  public static let intermittent = Self(rawValue: "intermittent")

  /// Isolated.
  public static let isolated = Self(rawValue: "isolated")

  /// Likely.
  public static let likely = Self(rawValue: "likely")

  /// Numerous.
  public static let numerous = Self(rawValue: "numerous")

  /// Occasional.
  public static let occasional = Self(rawValue: "occasional")

  /// Patchy.
  public static let patchy = Self(rawValue: "patchy")

  /// Periods of.
  public static let periods = Self(rawValue: "periods")

  /// Scattered.
  public static let scattered = Self(rawValue: "scattered")

  /// A slight chance.
  public static let slightChance = Self(rawValue: "slight_chance")

  /// Widespread.
  public static let widespread = Self(rawValue: "widespread")

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
