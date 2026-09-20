#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension Endpoint where Response == FeatureCollection<WeatherAlert> {
  /// Lists active alerts at a coordinate without a point-to-grid lookup.
  /// - Parameter location: The coordinate to filter.
  /// - Returns: The GeoJSON collection endpoint.
  public static func activeAlerts(for location: WeatherCoordinate) -> Self {
    activeAlerts(matching: .init(location: .point(location)))
  }

  /// Lists active alerts for a state, territory, or marine area.
  /// - Parameter area: A provider area code, encoded as one path segment.
  /// - Returns: The endpoint, or nil for an empty code or invalid encoded path.
  public static func activeAlerts(inArea area: AreaCode) -> Self? {
    guard !area.rawValue.isEmpty else { return nil }
    return Self(path: "/alerts/active/area/" + encodedSegment(area.rawValue))
  }

  /// Lists active alerts using a consumer-defined area enum.
  /// - Parameter area: A String-backed state, territory, or marine area code.
  /// - Returns: The endpoint, or nil for an empty code or invalid encoded path.
  public static func activeAlerts<Area>(inArea area: Area) -> Self?
  where Area: RawRepresentable, Area.RawValue == String {
    activeAlerts(inArea: AreaCode(area))
  }

  /// Lists active alerts for a marine region, `/alerts/active/region/{region}`.
  ///
  /// ```swift
  /// Endpoint.activeAlerts(inRegion: .gulfOfMexico)?.path  // "/alerts/active/region/GM"
  /// ```
  ///
  /// - Parameter region: A marine region code, encoded as one path segment.
  /// - Returns: The endpoint, or nil for an empty code or invalid encoded path.
  public static func activeAlerts(inRegion region: MarineRegionCode) -> Self? {
    guard !region.rawValue.isEmpty else { return nil }
    return Self(path: "/alerts/active/region/" + encodedSegment(region.rawValue))
  }

  /// Lists active alerts using a consumer-defined marine region enum.
  /// - Parameter region: A String-backed marine region code.
  /// - Returns: The endpoint, or nil for an empty code or invalid encoded path.
  public static func activeAlerts<Region>(inRegion region: Region) -> Self?
  where Region: RawRepresentable, Region.RawValue == String {
    activeAlerts(inRegion: MarineRegionCode(region))
  }

  /// Lists active alerts for a forecast or county zone.
  /// - Parameter zone: A nonempty provider zone identifier, encoded as one path segment.
  /// - Returns: The endpoint, or nil for an empty code or invalid encoded path.
  public static func activeAlerts(inZone zone: String) -> Self? {
    guard !zone.isEmpty else { return nil }
    return Self(path: "/alerts/active/zone/" + encodedSegment(zone))
  }

  /// Lists active alerts with the API's supported filters.
  /// - Parameter filter: The geographic and CAP restrictions.
  /// - Returns: The GeoJSON collection endpoint, which may redirect to a canonical URL.
  public static func activeAlerts(matching filter: ActiveAlertFilter = .init()) -> Self {
    builtIn(path: "/alerts/active" + filter.query)
  }
}

extension Endpoint where Response == FeatureCollection<WeatherAlert> {
  /// Lists alert history with the API's supported filters, time window, page size, and cursor.
  /// - Parameter query: The validated filters, window, page size, and initial cursor.
  /// - Returns: The GeoJSON collection endpoint, which may redirect to a canonical URL.
  public static func alerts(matching query: AlertQuery) -> Self {
    builtIn(path: "/alerts" + query.query)
  }
}

extension Endpoint where Response == ActiveAlertCount {
  /// Counts active alerts by region type, marine region, area, and zone, `/alerts/active/count`.
  ///
  /// The service offers this resource only as JSON-LD, so the endpoint asks for
  /// ``MediaType/jsonLD``.
  ///
  /// ```swift
  /// Endpoint.activeAlertCount.path  // "/alerts/active/count"
  /// ```
  public static var activeAlertCount: Self {
    builtIn(accept: .jsonLD, path: "/alerts/active/count")
  }
}

extension Endpoint where Response == AlertTypes {
  /// Lists the alert event names the service recognizes, `/alerts/types`.
  ///
  /// The service offers this resource only as JSON-LD, so the endpoint asks for
  /// ``MediaType/jsonLD``.
  ///
  /// ```swift
  /// Endpoint.alertTypes.path  // "/alerts/types"
  /// ```
  public static var alertTypes: Self {
    builtIn(accept: .jsonLD, path: "/alerts/types")
  }
}

extension Endpoint where Response == Feature<WeatherAlert> {
  /// Retrieves one alert by its provider identifier.
  /// - Parameter identifier: A nonempty alert identifier, encoded as one path segment.
  /// - Returns: The endpoint, or nil for an empty identifier or invalid encoded path.
  public static func alert(identifier: String) -> Self? {
    guard !identifier.isEmpty else { return nil }
    return Self(path: "/alerts/" + encodedSegment(identifier))
  }
}
