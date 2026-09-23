#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A forecast zone, a time window, and a limit for the zone's observations on
/// `/zones/forecast/{zoneId}/observations`.
///
/// Window bounds are sent as ISO 8601 instants in UTC with whole-second precision, and an absent
/// bound leaves that side of the window open. A nil limit omits the parameter so the service
/// applies its own size. The service decides which stations and observations a window matches and
/// how it orders them.
///
/// The service answers one response. Its continuation link does not continue the zone's list: the
/// recorded link names one station's observation history, so the SDK never follows it, and there
/// is no cursor to send.
///
/// ```swift
/// let query = try ZoneObservationQuery(limit: 10, zoneIdentifier: "TXZ192")
/// let endpoint = Endpoint.observations(inForecastZone: query)
/// ```
public struct ZoneObservationQuery: Hashable, Sendable {
  /// Why a zone observation query could not be created.
  public enum ValidationError: Error {
    /// The requested limit is outside 1 through 500.
    case invalidLimit
    /// The zone identifier is empty or produces an invalid encoded path.
    case invalidZoneIdentifier
  }

  /// The latest instant to include, or nil for no upper bound.
  public let end: Date?
  /// The maximum number of observations requested, or nil to omit the parameter.
  public let limit: Int?
  /// The earliest instant to include, or nil for no lower bound.
  public let start: Date?
  /// The forecast zone's identifier, such as `TXZ192`, encoded as one path segment.
  public let zoneIdentifier: String

  /// Creates a validated zone-observation query without sending it.
  /// - Parameters:
  ///   - end: The latest instant to include.
  ///   - limit: A limit from 1 through 500, or nil to omit the parameter.
  ///   - start: The earliest instant to include.
  ///   - zoneIdentifier: A nonempty forecast zone identifier.
  /// - Throws: ``ValidationError/invalidLimit`` for an unsupported limit, or
  ///   ``ValidationError/invalidZoneIdentifier`` for an empty identifier or invalid encoded path.
  public init(
    end: Date? = nil, limit: Int? = nil, start: Date? = nil, zoneIdentifier: String
  ) throws(ValidationError) {
    if let limit { guard (1...500).contains(limit) else { throw .invalidLimit } }
    guard Endpoint.observationStations(inForecastZone: zoneIdentifier) != nil else {
      throw .invalidZoneIdentifier
    }
    self.end = end
    self.limit = limit
    self.start = start
    self.zoneIdentifier = zoneIdentifier
  }

  var query: String {
    var items: [URLQueryItem] = []
    if let end { items.append(URLQueryItem(name: "end", value: end.formatted(.iso8601))) }
    if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
    if let start { items.append(URLQueryItem(name: "start", value: start.formatted(.iso8601))) }
    return URLComponents.nwsQuery(items)
  }
}
