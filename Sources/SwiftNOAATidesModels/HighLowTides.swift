/// Predicted high/low events accompanied by their requested, rather than provider-echoed, context.
public struct HighLowTides: Hashable, Sendable {
  /// Every decoded event in provider order, without sorting or deduplication.
  public let predictions: [HighLowTide]
  /// The validated station, datum, units, and GMT window used for this request.
  public let requestedQuery: HighLowTideQuery

  /// Attaches requested context to decoded events without converting their values.
  /// - Parameters:
  ///   - predictions: Events decoded from the matching response.
  ///   - requestedQuery: The query used to obtain those events.
  public init(predictions: [HighLowTide], requestedQuery: HighLowTideQuery) {
    self.predictions = predictions
    self.requestedQuery = requestedQuery
  }
}
