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
  ///   - session: The session that sends each request; defaults to the shared session.
  public init(configuration: NWSConfiguration, session: URLSession = .shared) {
    self.init(configuration: configuration, transport: URLSessionTransport(session: session))
  }
}

#endif
