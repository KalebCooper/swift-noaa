/// Predicted current predictions with requested context separate from provider-reported units.
///
/// Returned by `currentPredictions(matching:)`; values are not observations or navigation advice.
public struct CurrentPredictions: Hashable, Sendable {
  /// Provider predictions, retaining order and the actual returned values.
  public let predictions: [CurrentPrediction]
  /// Original validated query, not provider-echoed metadata.
  public let requestedQuery: CurrentPredictionQuery
  /// Exact provider-reported depth and velocity units.
  public let units: String

  /// Attaches the actual requested context to decoded predictions.
  /// - Parameters:
  ///   - predictions: Unchanged provider records.
  ///   - requestedQuery: The original query.
  ///   - units: Provider-reported units.
  public init(
    predictions: [CurrentPrediction], requestedQuery: CurrentPredictionQuery, units: String
  ) {
    self.predictions = predictions
    self.requestedQuery = requestedQuery
    self.units = units
  }
}
