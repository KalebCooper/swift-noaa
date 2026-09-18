/// An extensible marine-region code used by NWS active-alert filters, paths, and counts.
///
/// Named values match the live NWS schema. Unknown values remain available in ``rawValue``.
public struct MarineRegionCode: Codable, CodingKeyRepresentable, Hashable, RawRepresentable,
  Sendable
{
  /// Alaska waters.
  public static let alaska = Self(rawValue: "AL")

  /// Atlantic waters.
  public static let atlantic = Self(rawValue: "AT")

  /// Great Lakes waters.
  public static let greatLakes = Self(rawValue: "GL")

  /// Gulf of Mexico waters.
  public static let gulfOfMexico = Self(rawValue: "GM")

  /// Pacific waters.
  public static let pacific = Self(rawValue: "PA")

  /// Pacific Islands waters.
  public static let pacificIslands = Self(rawValue: "PI")

  /// The service's exact code, used as the key when a code keys a JSON object.
  public var codingKey: any CodingKey { Key(stringValue: rawValue) }

  /// The service's exact code.
  public let rawValue: String

  /// Creates a code from a consumer-defined String-backed value.
  public init<Value>(_ value: Value) where Value: RawRepresentable, Value.RawValue == String {
    self.init(rawValue: value.rawValue)
  }

  /// Creates a code from a JSON object key; every key is accepted as an exact service code.
  /// - Parameter codingKey: The key whose string value is the service's code.
  public init?<T: CodingKey>(codingKey: T) {
    self.init(rawValue: codingKey.stringValue)
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

  private struct Key: CodingKey {
    var intValue: Int? { nil }
    let stringValue: String

    init(stringValue: String) { self.stringValue = stringValue }

    init?(intValue: Int) { nil }
  }
}
