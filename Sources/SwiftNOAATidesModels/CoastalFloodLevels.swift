/// Raw flood thresholds, retaining NOS and NWS values independently.
///
/// Metric requests return meters and English requests return feet. The recorded resource does not
/// echo units or a reference datum; do not assume these values are comparable to a water-level
/// query merely because its units match. No sentinel, agency preference, or flood category is inferred.
public struct CoastalFloodLevels: Codable, Hashable, Sendable {
  /// Water-level action threshold; null is unavailable, while zero and negative numbers remain values.
  public let actionLevel: Double?
  /// NOS major threshold; null is unavailable, while zero and negative numbers remain values.
  public let nosMajor: Double?
  /// NOS minor threshold; null is unavailable, while zero and negative numbers remain values.
  public let nosMinor: Double?
  /// NOS moderate threshold; null is unavailable, while zero and negative numbers remain values.
  public let nosModerate: Double?
  /// NWS major threshold; null is unavailable, while zero and negative numbers remain values.
  public let nwsMajor: Double?
  /// NWS minor threshold; null is unavailable, while zero and negative numbers remain values.
  public let nwsMinor: Double?
  /// NWS moderate threshold; null is unavailable, while zero and negative numbers remain values.
  public let nwsModerate: Double?
  /// The provider's unchanged resource URL, when supplied.
  public let selfLink: String?

  private enum CodingKeys: String, CodingKey {
    case actionLevel = "action"
    case nosMajor = "nos_major"
    case nosMinor = "nos_minor"
    case nosModerate = "nos_moderate"
    case nwsMajor = "nws_major"
    case nwsMinor = "nws_minor"
    case nwsModerate = "nws_moderate"
    case selfLink = "self"
  }

  /// Decodes required nullable threshold fields without treating an absent table as empty success.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    actionLevel = try container.decode(Double?.self, forKey: .actionLevel)
    nosMajor = try container.decode(Double?.self, forKey: .nosMajor)
    nosMinor = try container.decode(Double?.self, forKey: .nosMinor)
    nosModerate = try container.decode(Double?.self, forKey: .nosModerate)
    nwsMajor = try container.decode(Double?.self, forKey: .nwsMajor)
    nwsMinor = try container.decode(Double?.self, forKey: .nwsMinor)
    nwsModerate = try container.decode(Double?.self, forKey: .nwsModerate)
    selfLink = try container.decodeIfPresent(String.self, forKey: .selfLink)
  }

  /// Encodes unavailable thresholds as explicit nulls, preserving the resource shape.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(actionLevel, forKey: .actionLevel)
    try container.encode(nosMajor, forKey: .nosMajor)
    try container.encode(nosMinor, forKey: .nosMinor)
    try container.encode(nosModerate, forKey: .nosModerate)
    try container.encode(nwsMajor, forKey: .nwsMajor)
    try container.encode(nwsMinor, forKey: .nwsMinor)
    try container.encode(nwsModerate, forKey: .nwsModerate)
    try container.encodeIfPresent(selfLink, forKey: .selfLink)
  }
}
