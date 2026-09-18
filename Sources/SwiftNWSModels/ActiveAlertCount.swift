/// The number of active alerts, broken down by region type, marine region, area, and zone, from
/// `/alerts/active/count`.
///
/// The breakdowns overlap rather than partition ``total``: one alert that affects several areas or
/// zones is counted once in each of them, so a breakdown's sum can exceed the total. The service
/// lists only areas, regions, and zones with at least one active alert; a code that is absent has no
/// active alerts at the time of the response. Counts are a snapshot and are not guaranteed to match a
/// later alert query.
///
/// ```swift
/// let count = try await weather.activeAlertCount()
/// print(count.total, count.areas[.texas] ?? 0, count.regions[.gulfOfMexico] ?? 0)
/// ```
public struct ActiveAlertCount: Codable, Hashable, Sendable {
  /// Active alerts by state, territory, or marine area code.
  public var areas: [AreaCode: Int]

  /// The number of active alerts affecting land zones.
  public var land: Int

  /// The number of active alerts affecting marine zones.
  public var marine: Int

  /// Active alerts by marine region code.
  public var regions: [MarineRegionCode: Int]

  /// The total number of active alerts.
  public var total: Int

  /// Active alerts by public forecast zone or county identifier, such as `TXZ192`.
  public var zones: [String: Int]

  /// Creates an active-alert count.
  ///
  /// - Parameters:
  ///   - areas: Active alerts by area code.
  ///   - land: The number of active alerts affecting land zones.
  ///   - marine: The number of active alerts affecting marine zones.
  ///   - regions: Active alerts by marine region code.
  ///   - total: The total number of active alerts.
  ///   - zones: Active alerts by zone identifier.
  public init(
    areas: [AreaCode: Int], land: Int, marine: Int, regions: [MarineRegionCode: Int], total: Int,
    zones: [String: Int]
  ) {
    self.areas = areas
    self.land = land
    self.marine = marine
    self.regions = regions
    self.total = total
    self.zones = zones
  }

  /// Decodes a count, accepting an empty JSON array for a breakdown with no entries.
  ///
  /// - Parameter decoder: The decoder to read from.
  /// - Throws: `DecodingError` when a required field is missing or has another shape.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    areas = try Self.breakdown(forKey: .areas, in: container)
    land = try container.decode(Int.self, forKey: .land)
    marine = try container.decode(Int.self, forKey: .marine)
    regions = try Self.breakdown(forKey: .regions, in: container)
    total = try container.decode(Int.self, forKey: .total)
    zones = try Self.breakdown(forKey: .zones, in: container)
  }

  private enum CodingKeys: String, CodingKey {
    case areas
    case land
    case marine
    case regions
    case total
    case zones
  }

  // A breakdown is a JSON object keyed by code. A serializer can write an empty object as an empty
  // array, which carries the same meaning: no code has an active alert.
  private static func breakdown<Key: Decodable & Hashable & CodingKeyRepresentable>(
    forKey key: CodingKeys, in container: KeyedDecodingContainer<CodingKeys>
  ) throws -> [Key: Int] {
    do {
      return try container.decode([Key: Int].self, forKey: key)
    } catch DecodingError.typeMismatch(let type, let context) {
      guard let empty = try? container.decode([Int].self, forKey: key), empty.isEmpty else {
        throw DecodingError.typeMismatch(type, context)
      }
      return [:]
    }
  }
}
