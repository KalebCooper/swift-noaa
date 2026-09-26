/// Metadata for one instrument bin, whose depth can change across deployments.
public struct CurrentBin: Codable, Hashable, Sendable {
  /// Depth in the table's reported units for an upward or downward sensor, when provided.
  public let depth: Double?
  /// Distance in the table's reported units for a sideways sensor, when provided.
  public let distance: Double?
  /// Whether NOAA marks this bin for public dissemination, not a guarantee of current data.
  public let isPublished: Bool?
  /// The provider's bin number.
  public let number: Int
  /// The reported ping interval, when provided.
  public let pingInterval: Int?
  /// The provider's quality-control flag, retaining unknown integer values.
  public let qualityFlag: Int?

  private enum CodingKeys: String, CodingKey {
    case depth
    case distance
    case isPublished = "is_pics"
    case number = "num"
    case pingInterval = "ping_int"
    case qualityFlag = "qc_flag"
  }
}
