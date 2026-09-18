/// An extensible code for a forecast weather phenomenon, such as `thunderstorms` or `rain_showers`.
///
/// Named values match the live NWS schema. Unknown service values remain available in ``rawValue``.
///
/// ```swift
/// if weather.phenomenon == .thunderstorms { print("Thunderstorms") }
/// ```
public struct ForecastWeatherPhenomenon: Codable, Hashable, RawRepresentable, Sendable {
  /// Blowing dust.
  public static let blowingDust = Self(rawValue: "blowing_dust")

  /// Blowing sand.
  public static let blowingSand = Self(rawValue: "blowing_sand")

  /// Blowing snow.
  public static let blowingSnow = Self(rawValue: "blowing_snow")

  /// Drizzle.
  public static let drizzle = Self(rawValue: "drizzle")

  /// Fog.
  public static let fog = Self(rawValue: "fog")

  /// Freezing drizzle.
  public static let freezingDrizzle = Self(rawValue: "freezing_drizzle")

  /// Freezing fog.
  public static let freezingFog = Self(rawValue: "freezing_fog")

  /// Freezing rain.
  public static let freezingRain = Self(rawValue: "freezing_rain")

  /// Freezing spray.
  public static let freezingSpray = Self(rawValue: "freezing_spray")

  /// Frost.
  public static let frost = Self(rawValue: "frost")

  /// Hail.
  public static let hail = Self(rawValue: "hail")

  /// Haze.
  public static let haze = Self(rawValue: "haze")

  /// Ice crystals.
  public static let iceCrystals = Self(rawValue: "ice_crystals")

  /// Ice fog.
  public static let iceFog = Self(rawValue: "ice_fog")

  /// Rain.
  public static let rain = Self(rawValue: "rain")

  /// Rain showers.
  public static let rainShowers = Self(rawValue: "rain_showers")

  /// Sleet.
  public static let sleet = Self(rawValue: "sleet")

  /// Smoke.
  public static let smoke = Self(rawValue: "smoke")

  /// Snow.
  public static let snow = Self(rawValue: "snow")

  /// Snow showers.
  public static let snowShowers = Self(rawValue: "snow_showers")

  /// Thunderstorms.
  public static let thunderstorms = Self(rawValue: "thunderstorms")

  /// Volcanic ash.
  public static let volcanicAsh = Self(rawValue: "volcanic_ash")

  /// Waterspouts.
  public static let waterSpouts = Self(rawValue: "water_spouts")

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
