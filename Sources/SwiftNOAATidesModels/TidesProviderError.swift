#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A provider refusal, preserving its message and an explicitly supplied metadata error code.
public struct TidesProviderError: Codable, Equatable, Sendable {
  /// The Metadata API's numeric code, absent for Data API errors.
  public let code: Int?
  /// The provider's explanation, without trimming or classification.
  public let message: String

  /// Creates a recorded provider refusal.
  /// - Parameters:
  ///   - code: A provider-supplied code, if present.
  ///   - message: The unchanged explanation.
  public init(code: Int?, message: String) {
    self.code = code
    self.message = message
  }
}
