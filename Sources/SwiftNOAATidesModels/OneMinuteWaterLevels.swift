/// Measured one-minute water levels with provider metadata and separate requested context.
///
/// Returned by `oneMinuteWaterLevels(matching:)`. Missing samples remain gaps.
public struct OneMinuteWaterLevels: Hashable, Sendable {
  /// Provider-reported station metadata, not reconstructed from the query.
  public let metadata: CoastalDataMetadata
  /// Observations in provider order, preserving missing quantities and time steps.
  public let observations: [OneMinuteWaterLevel]
  /// The original requested datum, units, station and inclusive GMT bounds.
  public let requestedQuery: OneMinuteWaterLevelQuery

  /// Combines decoded measurements and their original requested context.
  /// - Parameters:
  ///   - metadata: The provider's echoed metadata.
  ///   - observations: The unchanged observations.
  ///   - requestedQuery: The actual query that produced the response.
  public init(
    metadata: CoastalDataMetadata, observations: [OneMinuteWaterLevel],
    requestedQuery: OneMinuteWaterLevelQuery
  ) {
    self.metadata = metadata
    self.observations = observations
    self.requestedQuery = requestedQuery
  }
}
