/// Predicted current events with requested context separate from provider-reported units.
///
/// Returned by `currentEvents(matching:)`; values are not observations or navigation advice.
public struct CurrentEvents: Hashable, Sendable {
  /// Provider events, retaining order and the actual returned values.
  public let events: [CurrentEvent]
  /// Original validated query, not provider-echoed metadata.
  public let requestedQuery: CurrentEventQuery
  /// Exact provider-reported depth and velocity units.
  public let units: String

  /// Attaches the actual requested context to decoded predictions.
  /// - Parameters:
  ///   - events: Unchanged provider records.
  ///   - requestedQuery: The original query.
  ///   - units: Provider-reported units.
  public init(events: [CurrentEvent], requestedQuery: CurrentEventQuery, units: String) {
    self.events = events
    self.requestedQuery = requestedQuery
    self.units = units
  }
}
