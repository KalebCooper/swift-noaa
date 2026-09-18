/// An extensible kind of weather phenomenon a station reported, such as rain or fog.
///
/// Known values match the live NWS schema. Unknown service values remain available in ``rawValue``.
///
/// ```swift
/// if phenomenon.weather == .thunderstorms {
///   print(phenomenon.rawString)
/// }
/// ```
public struct WeatherPhenomenonKind: Codable, Hashable, RawRepresentable, Sendable {
  /// Drizzle, `DZ`.
  public static let drizzle = Self(rawValue: "drizzle")

  /// Widespread dust, `DU`.
  public static let dust = Self(rawValue: "dust")

  /// A dust storm, `DS`.
  public static let dustStorm = Self(rawValue: "dust_storm")

  /// Dust or sand whirls, `PO`.
  public static let dustWhirls = Self(rawValue: "dust_whirls")

  /// Fog, `FG`.
  public static let fog = Self(rawValue: "fog")

  /// Mist, `BR`.
  public static let fogMist = Self(rawValue: "fog_mist")

  /// A funnel cloud, tornado, or waterspout, `FC`.
  public static let funnelCloud = Self(rawValue: "funnel_cloud")

  /// Hail, `GR`.
  public static let hail = Self(rawValue: "hail")

  /// Haze, `HZ`.
  public static let haze = Self(rawValue: "haze")

  /// Ice crystals, `IC`.
  public static let iceCrystals = Self(rawValue: "ice_crystals")

  /// Ice pellets, `PL`.
  public static let icePellets = Self(rawValue: "ice_pellets")

  /// Rain, `RA`.
  public static let rain = Self(rawValue: "rain")

  /// Sand, `SA`.
  public static let sand = Self(rawValue: "sand")

  /// A sandstorm, `SS`.
  public static let sandStorm = Self(rawValue: "sand_storm")

  /// Smoke, `FU`.
  public static let smoke = Self(rawValue: "smoke")

  /// Snow, `SN`.
  public static let snow = Self(rawValue: "snow")

  /// Snow grains, `SG`.
  public static let snowGrains = Self(rawValue: "snow_grains")

  /// Small hail or snow pellets, `GS`.
  public static let snowPellets = Self(rawValue: "snow_pellets")

  /// Spray, `PY`.
  public static let spray = Self(rawValue: "spray")

  /// Squalls, `SQ`.
  public static let squalls = Self(rawValue: "squalls")

  /// A thunderstorm, `TS`.
  public static let thunderstorms = Self(rawValue: "thunderstorms")

  /// Precipitation an automated station could not identify, `UP`.
  public static let unknown = Self(rawValue: "unknown")

  /// Volcanic ash, `VA`.
  public static let volcanicAsh = Self(rawValue: "volcanic_ash")

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
