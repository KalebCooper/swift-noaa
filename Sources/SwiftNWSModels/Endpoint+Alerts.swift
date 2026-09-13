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
  /// - Parameter area: A nonempty provider area code, encoded as one path segment.
  /// - Returns: The GeoJSON collection endpoint.
  public static func activeAlerts(inArea area: String) -> Self {
    Self(path: "/alerts/active/area/" + encodedSegment(area))
  }

  /// Lists active alerts for a forecast or county zone.
  /// - Parameter zone: A nonempty provider zone identifier, encoded as one path segment.
  /// - Returns: The GeoJSON collection endpoint.
  public static func activeAlerts(inZone zone: String) -> Self {
    Self(path: "/alerts/active/zone/" + encodedSegment(zone))
  }

  /// Lists active alerts with the API's supported filters.
  /// - Parameter filter: The geographic and CAP restrictions.
  /// - Returns: The GeoJSON collection endpoint, which may redirect to a canonical URL.
  public static func activeAlerts(matching filter: ActiveAlertFilter = .init()) -> Self {
    Self(path: "/alerts/active" + filter.query)
  }
}

extension Endpoint where Response == Feature<WeatherAlert> {
  /// Retrieves one alert by its provider identifier.
  /// - Parameter identifier: A nonempty alert identifier, encoded as one path segment.
  /// - Returns: The GeoJSON alert endpoint.
  public static func alert(identifier: String) -> Self {
    Self(path: "/alerts/" + encodedSegment(identifier))
  }
}

extension Endpoint {
  static func encodedSegment(_ value: String) -> String {
    value.utf8.map { byte -> String in
      switch byte {
      case 45, 48...57, 65...90, 95, 97...122, 126:
        String(UnicodeScalar(byte))
      default:
        "%" + (byte < 16 ? "0" : "") + String(byte, radix: 16, uppercase: true)
      }
    }.joined()
  }
}
