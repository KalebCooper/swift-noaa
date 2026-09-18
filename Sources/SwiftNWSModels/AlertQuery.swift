#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Filters, a time window, a page size, and an initial cursor for alert history on `/alerts`.
///
/// The filter uses the same CAP and geographic vocabulary as the active-alert endpoint. Window
/// bounds are sent as ISO 8601 instants in UTC with whole-second precision. The service decides
/// which alerts a window matches and how it orders them; this type does not validate the window
/// against the filter, and an absent bound leaves that side of the window open.
///
/// ```swift
/// let query = try AlertQuery(
///   end: end, filter: .init(location: .areas([.texas]), status: [.actual]), limit: 100,
///   start: start)
/// let endpoint = Endpoint.alerts(matching: query)
/// ```
public struct AlertQuery: Hashable, Sendable {
  /// Why an alert query could not be created.
  public enum ValidationError: Error {
    /// The requested page size is outside 1 through 500.
    case invalidLimit
  }

  /// An opaque initial cursor, or nil to start at the first page.
  public let cursor: String?
  /// The latest instant to include, or nil for no upper bound.
  public let end: Date?
  /// The CAP and geographic restrictions; an empty filter includes every alert.
  public let filter: ActiveAlertFilter
  /// The maximum number of alerts requested per page.
  public let limit: Int
  /// The earliest instant to include, or nil for no lower bound.
  public let start: Date?

  /// Creates a validated alert-history query without sending it.
  /// - Parameters:
  ///   - cursor: An opaque initial cursor.
  ///   - end: The latest instant to include.
  ///   - filter: The CAP and geographic restrictions.
  ///   - limit: A page size from 1 through 500.
  ///   - start: The earliest instant to include.
  /// - Throws: ``ValidationError/invalidLimit`` for an unsupported page size.
  public init(
    cursor: String? = nil, end: Date? = nil, filter: ActiveAlertFilter = .init(), limit: Int = 500,
    start: Date? = nil
  ) throws(ValidationError) {
    guard (1...500).contains(limit) else { throw .invalidLimit }
    self.cursor = cursor
    self.end = end
    self.filter = filter
    self.limit = limit
    self.start = start
  }

  var query: String {
    var values = filter.queryValues
    if let cursor { values["cursor"] = cursor }
    if let end { values["end"] = end.formatted(.iso8601) }
    values["limit"] = String(limit)
    if let start { values["start"] = start.formatted(.iso8601) }
    return URLComponents.nwsQuery(
      values.keys.sorted().map { URLQueryItem(name: $0, value: values[$0]) })
  }
}
