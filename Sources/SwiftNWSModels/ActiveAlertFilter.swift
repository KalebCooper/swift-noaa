#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Filters accepted by the active-alert endpoint.
///
/// Location filters are mutually exclusive. Empty arrays omit their query parameter.
/// Area and marine-region codes expose the live vocabulary while preserving additions. Zone
/// identifiers and event names remain open; the service validates their vocabulary.
///
/// ```swift
/// let filter = ActiveAlertFilter(location: .point(home), severity: [.severe])
/// ```
public struct ActiveAlertFilter: Hashable, Sendable {
  /// One geographic restriction accepted by the API.
  public enum Location: Hashable, Sendable {
    /// State, territory, or marine area codes.
    case areas([AreaCode])
    /// A validated coordinate.
    case point(WeatherCoordinate)
    /// Land or marine alerts.
    case regionType(RegionType)
    /// Marine region codes.
    case regions([MarineRegionCode])
    /// Forecast or county zone identifiers.
    case zones([String])

    /// Creates an area location from a consumer-defined String-backed enum.
    public static func areas<Area>(_ areas: [Area]) -> Self
    where Area: RawRepresentable, Area.RawValue == String {
      var converted: [AreaCode] = []
      converted.reserveCapacity(areas.count)
      for area in areas {
        converted.append(AreaCode(area))
      }
      return .areas(converted)
    }

    /// Creates a marine-region location from a consumer-defined String-backed enum.
    public static func regions<Region>(_ regions: [Region]) -> Self
    where Region: RawRepresentable, Region.RawValue == String {
      var converted: [MarineRegionCode] = []
      converted.reserveCapacity(regions.count)
      for region in regions {
        converted.append(MarineRegionCode(region))
      }
      return .regions(converted)
    }
  }

  /// The region types accepted by the active-alert query.
  public enum RegionType: String, Hashable, Sendable {
    /// Land areas.
    case land
    /// Marine areas.
    case marine
  }

  /// The certainty codes to include.
  public var certainty: [AlertCertainty]
  /// The event codes to include.
  public var code: [String]
  /// The exact event names to include.
  public var event: [String]
  /// One geographic restriction, or nil for all locations.
  public var location: Location?
  /// The message types to include; the service accepts Alert, Cancel, and Update.
  public var messageType: [AlertMessageType]
  /// The severity codes to include.
  public var severity: [AlertSeverity]
  /// The status codes to include.
  public var status: [AlertStatus]
  /// The urgency codes to include.
  public var urgency: [AlertUrgency]

  /// Creates an active-alert filter.
  /// - Parameters:
  ///   - certainty: Certainty codes.
  ///   - code: Event codes.
  ///   - event: Exact event names.
  ///   - location: A geographic restriction.
  ///   - messageType: Message types.
  ///   - severity: Severity codes.
  ///   - status: Status codes.
  ///   - urgency: Urgency codes.
  public init(
    certainty: [AlertCertainty] = [], code: [String] = [], event: [String] = [],
    location: Location? = nil, messageType: [AlertMessageType] = [],
    severity: [AlertSeverity] = [], status: [AlertStatus] = [], urgency: [AlertUrgency] = []
  ) {
    self.certainty = certainty
    self.code = code
    self.event = event
    self.location = location
    self.messageType = messageType
    self.severity = severity
    self.status = status
    self.urgency = urgency
  }

  var query: String {
    var values: [String: String] = [:]
    func add(_ key: String, _ items: [String]) {
      if !items.isEmpty { values[key] = items.joined(separator: ",") }
    }
    add("certainty", certainty.map(\.rawValue))
    add("code", code)
    add("event", event)
    add("message_type", messageType.map { $0.rawValue.lowercased() })
    add("severity", severity.map(\.rawValue))
    add("status", status.map { $0.rawValue.lowercased() })
    add("urgency", urgency.map(\.rawValue))
    switch location {
    case .areas(let areas): add("area", areas.map(\.rawValue))
    case .point(let point):
      values["point"] = String(Endpoint.point(for: point).path.dropFirst("/points/".count))
    case .regionType(let type): values["region_type"] = type.rawValue
    case .regions(let regions): add("region", regions.map(\.rawValue))
    case .zones(let zones): add("zone", zones)
    case nil: break
    }
    var components = URLComponents()
    components.queryItems = values.keys.sorted().map { URLQueryItem(name: $0, value: values[$0]) }
    return components.percentEncodedQuery.map { $0.isEmpty ? "" : "?" + $0 } ?? ""
  }
}
