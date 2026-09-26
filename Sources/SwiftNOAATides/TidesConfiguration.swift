/// Optional identification for CO-OPS requests, independent of the NWS configuration.
public struct TidesConfiguration: Hashable, Sendable {
  /// The Data API application query value; nil omits it.
  public var application: String?
  /// An optional HTTP User-Agent value. CO-OPS does not require the NWS identity contract.
  public var userAgent: String?

  /// Creates identification values without I/O.
  /// - Parameters:
  ///   - application: A Data API caller identity, defaulting to swift-noaa.
  ///   - userAgent: An optional HTTP caller identity.
  public init(application: String? = "swift-noaa", userAgent: String? = nil) {
    self.application = application
    self.userAgent = userAgent
  }
}
