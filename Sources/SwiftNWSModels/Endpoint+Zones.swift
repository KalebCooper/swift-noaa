#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension Endpoint where Response == FeatureCollection<WeatherZone> {
  /// Lists zones of every type matching a query, `/zones`.
  ///
  /// The endpoint asks for GeoJSON with no feature flags and sends the query's filters plus an
  /// optional `type` filter. The service answers one response with no continuation; a limit caps
  /// that response. Recorded responses list zones with `null` geometry.
  ///
  /// ```swift
  /// let query = try ZoneQuery(areas: [.texas], limit: 2)
  /// Endpoint.zones(matching: query, types: [.county]).path  // "/zones?area=TX&limit=2&type=county"
  /// ```
  ///
  /// - Parameters:
  ///   - query: The validated filters.
  ///   - types: Zone types to include, or an empty array for every type.
  /// - Returns: The GeoJSON collection endpoint.
  public static func zones(matching query: ZoneQuery, types: [ZoneType] = []) -> Self {
    builtIn(path: "/zones" + query.query(types: types))
  }

  /// Lists zones of every type matching a query, using a consumer-defined zone type enum.
  /// - Parameters:
  ///   - query: The validated filters.
  ///   - types: String-backed zone types to include.
  /// - Returns: The GeoJSON collection endpoint.
  public static func zones<Kind>(matching query: ZoneQuery, types: [Kind]) -> Self
  where Kind: RawRepresentable, Kind.RawValue == String {
    zones(matching: query, types: types.map { ZoneType($0) })
  }

  /// Lists the zones of one type matching a query, `/zones/{type}`.
  ///
  /// The route's type decides which zones answer: the `forecast` route answers zones whose reported
  /// type is `public`. The endpoint asks for GeoJSON with no feature flags and sends only the
  /// query's filters; the route's type is never repeated as a query filter. The service answers one
  /// response with no continuation.
  ///
  /// ```swift
  /// let query = try ZoneQuery(areas: [.texas], limit: 2)
  /// Endpoint.zones(matching: query, ofType: .forecast)?.path  // "/zones/forecast?area=TX&limit=2"
  /// ```
  ///
  /// - Parameters:
  ///   - query: The validated filters.
  ///   - type: The route's zone type, encoded as one path segment.
  /// - Returns: The endpoint, or nil for an empty type or invalid encoded path.
  public static func zones(matching query: ZoneQuery, ofType type: ZoneType) -> Self? {
    guard let segment = zoneTypeSegment(type) else { return nil }
    return builtIn(path: "/zones/" + segment + query.query(types: []))
  }

  /// Lists the zones of one type matching a query, using a consumer-defined zone type enum.
  /// - Parameters:
  ///   - query: The validated filters.
  ///   - type: A String-backed zone type, encoded as one path segment.
  /// - Returns: The endpoint, or nil for an empty type or invalid encoded path.
  public static func zones<Kind>(matching query: ZoneQuery, ofType type: Kind) -> Self?
  where Kind: RawRepresentable, Kind.RawValue == String {
    zones(matching: query, ofType: ZoneType(type))
  }
}

extension Endpoint where Response == Feature<WeatherZone> {
  /// Retrieves one zone by type and identifier, `/zones/{type}/{zoneId}`.
  ///
  /// The endpoint asks for GeoJSON with no feature flags. Recorded responses carry the zone's
  /// polygon, which ``Feature/geometry`` retains. An effective instant is sent as ISO 8601 in UTC
  /// with whole-second precision and selects the definition in effect at that instant.
  ///
  /// ```swift
  /// Endpoint.zone(identifier: "TXZ192", type: .forecast)?.path  // "/zones/forecast/TXZ192"
  /// ```
  ///
  /// - Parameters:
  ///   - effective: The instant the definition must be effective at, or nil for the current one.
  ///   - identifier: The zone's identifier, such as `TXZ192`, encoded as one path segment.
  ///   - type: The route's zone type, encoded as one path segment.
  /// - Returns: The endpoint, or nil for an empty identifier or type or an invalid encoded path.
  public static func zone(effective: Date? = nil, identifier: String, type: ZoneType) -> Self? {
    guard let segment = zoneTypeSegment(type), !identifier.isEmpty else { return nil }
    let query = URLComponents.nwsQuery(
      effective.map { [URLQueryItem(name: "effective", value: $0.formatted(.iso8601))] } ?? [])
    return Self(path: "/zones/" + segment + "/" + encodedSegment(identifier) + query)
  }

  /// Retrieves one zone using a consumer-defined zone type enum.
  /// - Parameters:
  ///   - effective: The instant the definition must be effective at, or nil for the current one.
  ///   - identifier: The zone's identifier, encoded as one path segment.
  ///   - type: A String-backed zone type, encoded as one path segment.
  /// - Returns: The endpoint, or nil for an empty identifier or type or an invalid encoded path.
  public static func zone<Kind>(effective: Date? = nil, identifier: String, type: Kind) -> Self?
  where Kind: RawRepresentable, Kind.RawValue == String {
    zone(effective: effective, identifier: identifier, type: ZoneType(type))
  }
}

extension Endpoint {
  // Every typed zone route shares one validated type segment, and the SDK reports an unusable
  // type separately from an unusable identifier.
  package static func zoneTypeSegment(_ type: ZoneType) -> String? {
    guard !type.rawValue.isEmpty else { return nil }
    let segment = encodedSegment(type.rawValue)
    guard Self(path: "/zones/" + segment) != nil else { return nil }
    return segment
  }
}
