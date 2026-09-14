/// An extensible CAP alert-category code.
///
/// Known values match the live NWS schema. Unknown service values remain available in ``rawValue``.
public struct AlertCategory: Codable, Hashable, RawRepresentable, Sendable {
  /// Chemical, biological, radiological, nuclear, or high-yield explosive threats.
  public static let cbrne = Self(rawValue: "CBRNE")

  /// Environmental hazards.
  public static let environment = Self(rawValue: "Env")

  /// Fire suppression and rescue events.
  public static let fire = Self(rawValue: "Fire")

  /// Geophysical events.
  public static let geophysical = Self(rawValue: "Geo")

  /// Medical and public-health events.
  public static let health = Self(rawValue: "Health")

  /// Utility, telecommunication, and other infrastructure events.
  public static let infrastructure = Self(rawValue: "Infra")

  /// Meteorological events.
  public static let meteorological = Self(rawValue: "Met")

  /// Events outside the other categories.
  public static let other = Self(rawValue: "Other")

  /// Rescue and recovery events.
  public static let rescue = Self(rawValue: "Rescue")

  /// General emergency and public-safety events.
  public static let safety = Self(rawValue: "Safety")

  /// Law-enforcement and security events.
  public static let security = Self(rawValue: "Security")

  /// Transportation events.
  public static let transportation = Self(rawValue: "Transport")

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
