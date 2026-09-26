/// A current-bin metadata table, without a permanent bin-to-depth guarantee.
///
/// Returned by `currentBins(stationIdentifier:units:)`. A null table is preserved;
/// an invalid station can produce a zero-count null table instead of an error.
public struct CurrentBins: Codable, Hashable, Sendable {
  /// Reported bin size in the table units.
  public let binSize: Double?
  /// The reported bin array, or explicit null when NOAA has no table.
  public let bins: [CurrentBin]?
  /// Reported distance to the first bin center in the table units.
  public let centerOfFirstBinDistance: Double?
  /// Provider-reported number of bins.
  public let count: Int
  /// The provider's maximum public-dissemination bin field.
  public let maximumPublishedBin: Int?
  /// The provider's current default real-time bin, when provided.
  public let realTimeBin: Int?
  /// Reported depth/distance units, preserved independently of the request.
  public let units: String?
  /// Provider resource link retained as text and never fetched automatically.
  public let url: String?

  private enum CodingKeys: String, CodingKey {
    case binSize = "bin_size"
    case bins
    case centerOfFirstBinDistance = "center_bin_1_dist"
    case count = "nbr_of_bins"
    case maximumPublishedBin = "max_pics_bin"
    case realTimeBin = "real_time_bin"
    case units
    case url = "self"
  }

  /// Decodes the required bin-table envelope while preserving an explicit null array.
  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    binSize = try c.decodeIfPresent(Double.self, forKey: .binSize)
    bins = try c.decode([CurrentBin]?.self, forKey: .bins)
    centerOfFirstBinDistance = try c.decodeIfPresent(Double.self, forKey: .centerOfFirstBinDistance)
    count = try c.decode(Int.self, forKey: .count)
    maximumPublishedBin = try c.decodeIfPresent(Int.self, forKey: .maximumPublishedBin)
    realTimeBin = try c.decodeIfPresent(Int.self, forKey: .realTimeBin)
    units = try c.decodeIfPresent(String.self, forKey: .units)
    url = try c.decodeIfPresent(String.self, forKey: .url)
  }
  /// Encodes the table, retaining an explicit null bin array.
  public func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encodeIfPresent(binSize, forKey: .binSize)
    try c.encode(bins, forKey: .bins)
    try c.encodeIfPresent(centerOfFirstBinDistance, forKey: .centerOfFirstBinDistance)
    try c.encode(count, forKey: .count)
    try c.encodeIfPresent(maximumPublishedBin, forKey: .maximumPublishedBin)
    try c.encodeIfPresent(realTimeBin, forKey: .realTimeBin)
    try c.encodeIfPresent(units, forKey: .units)
    try c.encodeIfPresent(url, forKey: .url)
  }

}
