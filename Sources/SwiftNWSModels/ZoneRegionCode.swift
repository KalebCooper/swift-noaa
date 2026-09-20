/// An extensible region code accepted by the zone directory's `region` filter.
///
/// The filter accepts both the six land regions, which are the NWS regional headquarters, and the
/// six marine regions that ``MarineRegionCode`` names. Named values match the live NWS schema, and
/// unknown values remain available in ``rawValue``. Marine members share their names and codes with
/// ``MarineRegionCode``; land members end in `Region`.
///
/// ```swift
/// let query = try ZoneQuery(regions: [.southernRegion, .gulfOfMexico])
/// let marine = ZoneRegionCode(MarineRegionCode.atlantic)  // .atlantic
/// ```
public struct ZoneRegionCode: Codable, Hashable, RawRepresentable, Sendable {
  // MARK: Land regions

  /// The Alaska Region headquarters.
  public static let alaskaRegion = Self(rawValue: "AR")

  /// The Central Region headquarters.
  public static let centralRegion = Self(rawValue: "CR")

  /// The Eastern Region headquarters.
  public static let easternRegion = Self(rawValue: "ER")

  /// The Pacific Region headquarters.
  public static let pacificRegion = Self(rawValue: "PR")

  /// The Southern Region headquarters.
  public static let southernRegion = Self(rawValue: "SR")

  /// The Western Region headquarters.
  public static let westernRegion = Self(rawValue: "WR")

  // MARK: Marine regions

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

  /// The service's exact code.
  public let rawValue: String

  /// Creates a code from a consumer-defined String-backed value.
  public init<Value>(_ value: Value) where Value: RawRepresentable, Value.RawValue == String {
    self.init(rawValue: value.rawValue)
  }

  /// Creates a code from a marine region code, keeping its exact value.
  /// - Parameter region: A marine region accepted by the active-alert endpoints.
  public init(_ region: MarineRegionCode) {
    self.init(rawValue: region.rawValue)
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
