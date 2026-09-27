/// The latest successful water-level response with separate requested context.
/// An empty success has no observation; provider refusals remain execution errors.
public struct LatestWaterLevel: Hashable, Sendable {
  /// Station metadata actually echoed by the provider.
  public let metadata: CoastalDataMetadata
  /// The sole reported reading, or nil for a successful empty array.
  public let observation: WaterLevel?
  /// The original station, datum and units; no date range is manufactured.
  public let requestedQuery: LatestWaterLevelQuery

  /// Combines a decoded result with its actual request.
  /// - Parameters:
  ///   - metadata: Provider-echoed station metadata.
  ///   - observation: The sole reading, or nil for empty success.
  ///   - requestedQuery: The original latest selector.
  public init(
    metadata: CoastalDataMetadata, observation: WaterLevel?, requestedQuery: LatestWaterLevelQuery
  ) {
    self.metadata = metadata
    self.observation = observation
    self.requestedQuery = requestedQuery
  }
}
