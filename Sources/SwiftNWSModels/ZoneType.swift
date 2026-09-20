/// An extensible zone type, named by the typed zone routes and reported in zone properties.
///
/// Named values match the live NWS schema. Unknown values remain available in ``rawValue``. The
/// type in a route and the type a zone reports can differ: the `forecast` route answers zones
/// whose reported type is `public`, and the `marine` route answers `coastal` and `offshore` zones.
///
/// ```swift
/// let endpoint = Endpoint.zone(identifier: "TXZ192", type: .forecast)
/// let reported = ZoneType(rawValue: "public")
/// ```
public struct ZoneType: Codable, Hashable, RawRepresentable, Sendable {
  /// A coastal marine zone.
  public static let coastal = Self(rawValue: "coastal")

  /// A county zone.
  public static let county = Self(rawValue: "county")

  /// A fire weather zone.
  public static let fire = Self(rawValue: "fire")

  /// The forecast zone route, which answers public forecast zones.
  public static let forecast = Self(rawValue: "forecast")

  /// A land zone.
  public static let land = Self(rawValue: "land")

  /// The marine zone route, which answers coastal and offshore zones.
  public static let marine = Self(rawValue: "marine")

  /// An offshore marine zone.
  public static let offshore = Self(rawValue: "offshore")

  /// A public forecast zone, as the forecast route reports it.
  public static let `public` = Self(rawValue: "public")

  /// The service's exact code.
  public let rawValue: String

  /// Creates a code from a consumer-defined String-backed value.
  public init<Value>(_ value: Value) where Value: RawRepresentable, Value.RawValue == String {
    self.init(rawValue: value.rawValue)
  }

  /// Creates a code without restricting future service values.
  public init(rawValue: String) { self.rawValue = rawValue }

  /// Decodes the exact service code.
  public init(from decoder: any Decoder) throws {
    rawValue = try decoder.singleValueContainer().decode(String.self)
  }

  /// Encodes the exact service code.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
