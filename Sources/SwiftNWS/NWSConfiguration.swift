/// The values every request to the National Weather Service API is sent with.
///
/// The API has no key, but it rejects a request without a `User-Agent` that identifies the
/// application and a way to contact its developer. There is no default: the value is yours to state.
///
/// ```swift
/// let configuration = NWSConfiguration(userAgent: "(myweatherapp.com, contact@myweatherapp.com)")
/// ```
public struct NWSConfiguration: Hashable, Sendable {
  /// The `User-Agent` sent with every request, identifying the application and a contact.
  public var userAgent: String

  /// Creates a configuration.
  ///
  /// - Parameter userAgent: The `User-Agent` sent with every request. Name the application and a
  ///   way to reach its developer, such as a website or an email address.
  public init(userAgent: String) {
    self.userAgent = userAgent
  }
}
