#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A forecast office's answer to `/offices/{officeId}/briefing`: its current briefing, or none.
///
/// The `briefing` key is required. Its value is the briefing's metadata, or `null` when the office
/// has no current briefing, which decodes as a nil ``briefing``. A body without the key, or with a
/// value that is neither an object nor `null`, fails to decode. The response's JSON-LD context is
/// not kept.
///
/// ```swift
/// if let endpoint = Endpoint.officeBriefing(officeIdentifier: "EWX") {
///   let response = try await weather.send(endpoint)
///   print(response.briefing == nil)  // true when the office has no current briefing
/// }
/// ```
public struct OfficeBriefingResponse: Codable, Hashable, Sendable {
  /// The office's current briefing, or nil when the service reports none.
  public var briefing: OfficeBriefing?

  /// Creates a briefing response.
  /// - Parameter briefing: The office's current briefing, or nil for none.
  public init(briefing: OfficeBriefing?) {
    self.briefing = briefing
  }

  /// Decodes a briefing response, requiring the `briefing` key even when its value is `null`.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError` for a missing `briefing` key, a value that is neither an object nor
  ///   `null`, or briefing metadata that fails to decode.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(briefing: try container.decode(OfficeBriefing?.self, forKey: .briefing))
  }

  /// Encodes the briefing response, writing `null` when there is no current briefing.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(briefing, forKey: .briefing)
  }

  private enum CodingKeys: String, CodingKey {
    case briefing
  }
}

/// The `briefing` wrapper of `/offices/{officeId}/briefing`, generic over the value it carries so
/// a request can return that value directly.
///
/// The `briefing` key is required; when `Value` is optional, a `null` value decodes as nil.
package struct BriefingEnvelope<Value: Decodable>: Decodable {
  package var briefing: Value
}
