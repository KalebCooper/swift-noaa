/// Measured currents with provider metadata and separate requested context.
///
/// Returned by `currentObservations(matching:)`. Predictions are not subtracted and gaps are not filled.
public struct CurrentObservations: Hashable, Sendable {
  /// Provider-reported station metadata, not reconstructed from the query.
  public let metadata: CoastalDataMetadata
  /// Observations in provider order, preserving missing quantities and time steps.
  public let observations: [CurrentObservation]
  /// The original requested bin choice, units, station and inclusive GMT bounds.
  public let requestedQuery: CurrentObservationQuery

  /// Combines decoded measurements and their original requested context.
  /// - Parameters:
  ///   - metadata: The provider's echoed metadata.
  ///   - observations: The unchanged observations.
  ///   - requestedQuery: The actual query that produced the response.
  public init(
    metadata: CoastalDataMetadata, observations: [CurrentObservation],
    requestedQuery: CurrentObservationQuery
  ) {
    self.metadata = metadata
    self.observations = observations
    self.requestedQuery = requestedQuery
  }
}
