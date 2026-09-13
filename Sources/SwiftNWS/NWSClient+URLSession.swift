// `URLSession` exists only on Apple platforms, so this initializer compiles only where it does.
#if canImport(Darwin)

import Foundation
import HTTPURLSession

extension NWSClient {
  /// Creates a client that sends through a `URLSession`.
  ///
  /// ```swift
  /// let client = NWSClient(
  ///   configuration: NWSConfiguration(userAgent: "(myweatherapp.com, contact@myweatherapp.com)")
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - configuration: The values every request is sent with.
  ///   - pointCache: Shared point mappings, or nil to disable caching.
  ///   - session: The session that sends each request; defaults to the shared session.
  public init(
    configuration: NWSConfiguration, pointCache: PointCache? = .init(),
    session: URLSession = .shared
  ) {
    self.init(
      configuration: configuration, pointCache: pointCache,
      transport: URLSessionTransport(session: session))
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
