#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A station, a time window, a page size, and an initial cursor for observation history on
/// `/stations/{stationId}/observations`.
///
/// Window bounds are sent as ISO 8601 instants in UTC with whole-second precision, and an absent
/// bound leaves that side of the window open. A nil limit omits the parameter so the service
/// applies its own page size. The service decides which observations a window matches and how it
/// orders them; recorded responses list the newest observation first, but that order is not a
/// documented guarantee.
///
/// ```swift
/// let query = try ObservationQuery(limit: 24, start: start, stationIdentifier: "KATT")
/// let endpoint = Endpoint.observations(query: query)
/// ```
public struct ObservationQuery: Hashable, Sendable {
  /// Why an observation query could not be created.
  public enum ValidationError: Error {
    /// The requested page size is outside 1 through 500.
    case invalidLimit
    /// The station identifier is empty.
    case invalidStationIdentifier
  }

  /// An opaque initial cursor, or nil to start at the first page.
  public let cursor: String?
  /// The latest instant to include, or nil for no upper bound.
  public let end: Date?
  /// The maximum number of observations requested per page, or nil for the service's page size.
  public let limit: Int?
  /// The earliest instant to include, or nil for no lower bound.
  public let start: Date?
  /// The station's identifier, such as `KATT`, encoded as one path segment.
  public let stationIdentifier: String

  /// Creates a validated observation-history query without sending it.
  /// - Parameters:
  ///   - cursor: An opaque initial cursor.
  ///   - end: The latest instant to include.
  ///   - limit: A page size from 1 through 500, or nil for the service's page size.
  ///   - start: The earliest instant to include.
  ///   - stationIdentifier: A nonempty station identifier.
  /// - Throws: ``ValidationError/invalidLimit`` for an unsupported page size, or
  ///   ``ValidationError/invalidStationIdentifier`` for an empty identifier.
  public init(
    cursor: String? = nil, end: Date? = nil, limit: Int? = nil, start: Date? = nil,
    stationIdentifier: String
  ) throws(ValidationError) {
    if let limit { guard (1...500).contains(limit) else { throw .invalidLimit } }
    guard !stationIdentifier.isEmpty else { throw .invalidStationIdentifier }
    self.cursor = cursor
    self.end = end
    self.limit = limit
    self.start = start
    self.stationIdentifier = stationIdentifier
  }

  var query: String {
    var items: [URLQueryItem] = []
    if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
    if let end { items.append(URLQueryItem(name: "end", value: end.formatted(.iso8601))) }
    if let limit { items.append(URLQueryItem(name: "limit", value: String(limit))) }
    if let start { items.append(URLQueryItem(name: "start", value: start.formatted(.iso8601))) }
    return URLComponents.nwsQuery(items)
  }
}
