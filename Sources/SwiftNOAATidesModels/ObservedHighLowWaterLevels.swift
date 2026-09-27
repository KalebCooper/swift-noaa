/// Measured verified observed extrema with provider metadata and separate requested context.
///
/// Returned by `observedHighLowWaterLevels(matching:)`. Events are neither predicted nor calculated from sampled measurements.
public struct ObservedHighLowWaterLevels: Hashable, Sendable {
  /// Provider-reported station metadata, not reconstructed from the query.
  public let metadata: CoastalDataMetadata
  /// Events in unchanged provider order; omitted events are never fabricated.
  public let observations: [ObservedHighLowWaterLevel]
  /// The original requested datum, units, station and inclusive GMT bounds.
  public let requestedQuery: ObservedHighLowWaterLevelQuery

  /// Combines decoded measurements and their original requested context.
  /// - Parameters:
  ///   - metadata: The provider's echoed metadata.
  ///   - observations: The unchanged observations.
  ///   - requestedQuery: The actual query that produced the response.
  public init(
    metadata: CoastalDataMetadata, observations: [ObservedHighLowWaterLevel],
    requestedQuery: ObservedHighLowWaterLevelQuery
  ) {
    self.metadata = metadata
    self.observations = observations
    self.requestedQuery = requestedQuery
  }
}
