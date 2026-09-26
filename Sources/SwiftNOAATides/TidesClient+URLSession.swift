#if canImport(Darwin)
import Foundation
import HTTPURLSession

extension TidesClient {
  /// Creates an Apple-platform client with optional caller identification.
  /// - Parameters:
  ///   - clock: The clock used by an explicitly enabled retry policy.
  ///   - configuration: Optional application and User-Agent values.
  ///   - retryPolicy: The swifty-networking policy, disabled by default.
  ///   - session: The URL session used for requests.
  public init(
    clock: any Clock<Duration> = ContinuousClock(),
    configuration: TidesConfiguration = .init(),
    retryPolicy: RetryPolicy = .disabled,
    session: URLSession = .shared
  ) {
    self.init(
      clock: clock, configuration: configuration, retryPolicy: retryPolicy,
      transport: URLSessionTransport(session: session))
  }
}
#endif
