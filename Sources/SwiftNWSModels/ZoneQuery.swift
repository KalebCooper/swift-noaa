#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Filters for the zone directory on `/zones` and `/zones/{type}`.
///
/// Empty arrays and nil options omit their parameters, so `try ZoneQuery()` lists every zone the
/// service is willing to return. Array filters are sent comma-separated in the supplied order. An
/// explicit `false` geometry option is sent as `include_geometry=false`. The effective instant is
/// sent as ISO 8601 in UTC with whole-second precision, and a point is sent with the four-decimal
/// precision the service accepts.
///
/// The service declares no page size, default, or cursor for the directory: a limit only caps one
/// response, and the response carries no continuation. Recorded directory responses have `null`
/// geometry even when geometry is requested, so the option is sent as documented without any
/// promise that the service honors it.
///
/// ```swift
/// let query = try ZoneQuery(areas: [.texas], limit: 10)
/// let endpoint = Endpoint.zones(matching: query, types: [.county])
/// ```
public struct ZoneQuery: Hashable, Sendable {
  /// Why a zone query could not be created.
  public enum ValidationError: Error {
    /// The requested limit is less than 1.
    case invalidLimit
  }

  /// State, territory, or marine area codes to include; the service validates their vocabulary.
  public let areas: [AreaCode]
  /// The instant the zone definitions must be effective at, or nil for the current definitions.
  public let effective: Date?
  /// Zone identifiers to include, in the supplied order.
  public let identifiers: [String]
  /// Whether to ask for geometry in the results, or nil to omit the parameter.
  public let includesGeometry: Bool?
  /// The maximum number of zones requested, or nil to omit the parameter.
  public let limit: Int?
  /// A coordinate the zones must contain, or nil for no location restriction.
  public let point: WeatherCoordinate?
  /// Land or marine region codes to include; the service validates their vocabulary.
  public let regions: [ZoneRegionCode]

  /// Creates a validated zone-directory query without sending it.
  /// - Parameters:
  ///   - areas: Area codes, or an empty array for all areas.
  ///   - effective: The instant the definitions must be effective at.
  ///   - identifiers: Zone identifiers, or an empty array for all identifiers.
  ///   - includesGeometry: Whether to request geometry, or nil to omit the parameter.
  ///   - limit: A positive maximum number of zones, or nil to omit the parameter.
  ///   - point: A coordinate the zones must contain.
  ///   - regions: Region codes, or an empty array for all regions.
  /// - Throws: ``ValidationError/invalidLimit`` for a limit less than 1.
  public init(
    areas: [AreaCode] = [], effective: Date? = nil, identifiers: [String] = [],
    includesGeometry: Bool? = nil, limit: Int? = nil, point: WeatherCoordinate? = nil,
    regions: [ZoneRegionCode] = []
  ) throws(ValidationError) {
    if let limit { guard limit >= 1 else { throw .invalidLimit } }
    self.areas = areas
    self.effective = effective
    self.identifiers = identifiers
    self.includesGeometry = includesGeometry
    self.limit = limit
    self.point = point
    self.regions = regions
  }

  // The root directory's type filter is a factory parameter rather than a field, so the typed
  // route never sends a query type that competes with its path type.
  func query(types: [ZoneType]) -> String {
    var items: [URLQueryItem] = []
    if !areas.isEmpty {
      items.append(URLQueryItem(name: "area", value: areas.map(\.rawValue).joined(separator: ",")))
    }
    if let effective {
      items.append(URLQueryItem(name: "effective", value: effective.formatted(.iso8601)))
    }
    if !identifiers.isEmpty {
      items.append(URLQueryItem(name: "id", value: identifiers.joined(separator: ",")))
    }
    if let includesGeometry {
      items.append(URLQueryItem(name: "include_geometry", value: String(includesGeometry)))
    }
    if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
    if let point {
      items.append(
        URLQueryItem(
          name: "point", value: String(Endpoint.point(for: point).path.dropFirst("/points/".count))
        ))
    }
    if !regions.isEmpty {
      items.append(
        URLQueryItem(name: "region", value: regions.map(\.rawValue).joined(separator: ",")))
    }
    if !types.isEmpty {
      items.append(URLQueryItem(name: "type", value: types.map(\.rawValue).joined(separator: ",")))
    }
    return URLComponents.nwsQuery(items)
  }
}
