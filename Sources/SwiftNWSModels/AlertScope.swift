/// An extensible CAP distribution-scope code.
///
/// Known values match the live NWS schema. Unknown service values remain available in ``rawValue``.
public struct AlertScope: Codable, Hashable, RawRepresentable, Sendable {
  /// Distribution is limited to named addresses.
  public static let `private` = Self(rawValue: "Private")

  /// Distribution is unrestricted.
  public static let `public` = Self(rawValue: "Public")

  /// Distribution is limited as described by the sender.
  public static let restricted = Self(rawValue: "Restricted")

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
