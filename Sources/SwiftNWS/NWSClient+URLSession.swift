// `URLSession` exists only on Apple platforms, so this initializer compiles only where it does.
#if canImport(Darwin)

import Foundation
import HTTPURLSession

extension NWSClient {
  /// Creates a client that sends through a `URLSession`.
  ///
  /// The client sends each request once unless you pass a retry policy. See
  /// ``init(clock:configuration:pointCache:retryPolicy:transport:)`` for how retries are timed
  /// and budgeted.
  ///
  /// ```swift
  /// let client = NWSClient(
  ///   configuration: NWSConfiguration(userAgent: "(myweatherapp.com, contact@myweatherapp.com)"),
  ///   retryPolicy: .transientServiceFailures
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - clock: The clock that times the waits between attempts; defaults to a continuous clock.
  ///     The point cache keeps its own clock.
  ///   - configuration: The values every request is sent with.
  ///   - pointCache: Shared point mappings, or nil to disable caching.
  ///   - retryPolicy: Which failed requests are sent again, how often, and after what wait;
  ///     defaults to `RetryPolicy.disabled`, which sends each request once.
  ///   - session: The session that sends each request; defaults to the shared session.
  public init(
    clock: any Clock<Duration> = ContinuousClock(), configuration: NWSConfiguration,
    pointCache: PointCache? = .init(), retryPolicy: RetryPolicy = .disabled,
    session: URLSession = .shared
  ) {
    self.init(
      clock: clock, configuration: configuration, pointCache: pointCache,
      retryPolicy: retryPolicy, transport: URLSessionTransport(session: session))
  }

  /// Creates a client that sends through the shared URL session.
  ///
  /// - Parameter userAgent: Your application identity and a contact, such as
  ///   `(myweatherapp.com, contact@myweatherapp.com)`. There is no default identity.
  public init(userAgent: String) {
    self.init(configuration: NWSConfiguration(userAgent: userAgent))
  }
}

#endif
