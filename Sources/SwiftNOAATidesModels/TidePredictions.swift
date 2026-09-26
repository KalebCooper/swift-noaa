/// Sampled tide predictions with their original requested context.
///
/// Returned by `tidePredictions(matching:)`. The query is requested context, not provider metadata.
public struct TidePredictions: Hashable, Sendable {
  /// Reported samples in provider order.
  public let predictions: [TidePrediction]
  /// The original explicit request, without inferred station capabilities.
  public let requestedQuery: TidePredictionQuery

  /// Combines decoded samples and the request that produced them.
  /// - Parameters:
  ///   - predictions: The unchanged decoded samples.
  ///   - requestedQuery: The actual request, never reconstructed from sample values.
  public init(predictions: [TidePrediction], requestedQuery: TidePredictionQuery) {
    self.predictions = predictions
    self.requestedQuery = requestedQuery
  }
}
