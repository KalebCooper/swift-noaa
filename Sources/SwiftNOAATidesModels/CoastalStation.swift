#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A directory or detail station as the provider describes it.
/// Names, empty text, capabilities, and resource links retain list/detail differences.
/// Links are metadata and are never fetched automatically; time zones are not IANA identifiers.
public struct CoastalStation: Codable, Equatable, Sendable {
  /// The provider's `affiliations` field, without normalization.
  public let affiliations: String?

  /// The provider's `benchmarks` field, without normalization.
  public let benchmarks: CoastalResource?

  /// Bin-table resource, not automatically expanded.
  public let bins: CoastalResource?

  /// Reported first-bin center distance; units belong to the station envelope.
  public let centerOfFirstBinDistance: Double?

  /// Current-prediction bin number for this directory entry.
  public let currentBin: Int?

  /// Current-prediction offsets resource, never fetched automatically.
  public let currentPredictionOffsets: CoastalResource?

  /// The provider's `datums` field, without normalization.
  public let datums: CoastalResource?

  /// Deployment time as provider text, with no assumed UTC offset.
  public let deployed: String?

  /// Deployment-history resource, not automatically expanded.
  public let deployments: CoastalResource?

  /// Reported current-prediction depth in envelope units, when provided.
  public let depth: Double?

  /// Provider depth-reference code, preserving unknown values.
  public let depthType: String?

  /// The provider's `details` field, without normalization.
  public let details: CoastalResource?

  /// The provider's `disclaimers` field, without normalization.
  public let disclaimers: CoastalResource?

  /// The provider's `expand` field, without normalization.
  public let expansion: String?

  /// The provider's `floodlevels` field, without normalization.
  public let floodLevels: CoastalResource?

  /// The provider's `forecast` field, without normalization.
  public let forecast: Bool?

  /// The provider's `greatlakes` field, without normalization.
  public let greatLakes: Bool?

  /// The provider's `harmonicConstituents` field, without normalization.
  public let harmonicConstituents: CoastalResource?

  /// Reported instrument height from bottom in station-envelope units.
  public let heightFromBottom: Double?

  /// The provider's `HTFhistorical` field, without normalization.
  public let highTideFloodingHistorical: Bool?

  /// The provider's `HTFmonthly` field, without normalization.
  public let highTideFloodingMonthly: Bool?

  /// The provider's `id` field, without normalization.
  public let identifier: String

  /// The provider's `inundationdb` field, without normalization.
  public let inundationDatabase: Bool?

  /// The provider's `type` field, without normalization.
  public let kind: CoastalStationKind?

  /// The provider's `lat` field, without normalization.
  public let latitude: Double

  /// The provider's `lng` field, without normalization.
  public let longitude: Double

  /// The provider's `name` field, without normalization.
  public let name: String

  /// The provider's `nearby` field, without normalization.
  public let nearby: CoastalResource?

  /// The provider's NOAA chart number.
  public let noaaChart: Int?

  /// The provider's `nonNavigational` field, without normalization.
  public let nonNavigational: Bool?

  /// The provider's `notices` field, without normalization.
  public let notices: CoastalResource?

  /// The provider's `observedst` field, without normalization.
  public let observesDaylightSavingTime: Bool?

  /// The provider's `ofsMapOffsets` field, without normalization.
  public let ofsMapOffsets: CoastalResource?

  /// The provider's `outlook` field, without normalization.
  public let outlook: Bool?

  /// The provider's `portscode` field, without normalization.
  public let portsCode: String?

  /// The provider's `products` field, without normalization.
  public let products: CoastalResource?

  /// Current survey or PORTS project name.
  public let project: String?

  /// Provider project-type text, retaining unknown values.
  public let projectType: String?

  /// The provider's `reference_id` field, without normalization.
  public let referenceIdentifier: String?

  /// Retrieval time as provider text, retaining empty strings.
  public let retrieved: String?

  /// The provider's `sensors` field, without normalization.
  public let sensors: CoastalResource?

  /// The provider's `shefcode` field, without normalization.
  public let shefCode: String?

  /// The provider's `state` field, without normalization.
  public let state: String?

  /// The provider's `stormsurge` field, without normalization.
  public let stormSurge: Bool?

  /// The provider's `supersededdatums` field, without normalization.
  public let supersededDatums: CoastalResource?

  /// The provider's `tidal` field, without normalization.
  public let tidal: Bool?

  /// The provider's `tidePredOffsets` field, without normalization.
  public let tidePredictionOffsets: CoastalResource?

  /// The provider's `tidepredoffsets` field, without normalization.
  public let tidePredictionOffsetsDirectory: CoastalResource?

  /// The provider's `tideType` field, without normalization.
  public let tideType: String?

  /// The provider's `timemeridian` field, without normalization.
  public let timeMeridian: Double?

  /// The provider's `timezone` field, without normalization.
  public let timeZone: String?

  /// The provider's `timezonecorr` field, without normalization.
  public let timeZoneCorrection: Double?

  /// Provider offset text, without inferring an IANA time zone.
  public let timeZoneOffset: String?

  /// The provider's `self` field, without normalization.
  public let url: String?

  private enum CodingKeys: String, CodingKey {
    case affiliations
    case benchmarks
    case bins
    case centerOfFirstBinDistance = "center_bin_1_dist"
    case currentBin = "currbin"
    case currentPredictionOffsets = "currentpredictionoffsets"
    case datums
    case deployed
    case deployments
    case depth
    case depthType
    case details
    case disclaimers
    case expansion = "expand"
    case floodLevels = "floodlevels"
    case forecast
    case greatLakes = "greatlakes"
    case harmonicConstituents
    case heightFromBottom = "height_from_bottom"
    case highTideFloodingHistorical = "HTFhistorical"
    case highTideFloodingMonthly = "HTFmonthly"
    case identifier = "id"
    case inundationDatabase = "inundationdb"
    case kind = "type"
    case latitude = "lat"
    case longitude = "lng"
    case name
    case nearby
    case noaaChart = "noaachart"
    case nonNavigational
    case notices
    case observesDaylightSavingTime = "observedst"
    case ofsMapOffsets
    case outlook
    case portsCode = "portscode"
    case products
    case project
    case projectType = "project_type"
    case referenceIdentifier = "reference_id"
    case retrieved
    case sensors
    case shefCode = "shefcode"
    case state
    case stormSurge = "stormsurge"
    case supersededDatums = "supersededdatums"
    case tidal
    case tidePredictionOffsets = "tidePredOffsets"
    case tidePredictionOffsetsDirectory = "tidepredoffsets"
    case tideType
    case timeMeridian = "timemeridian"
    case timeZone = "timezone"
    case timeZoneCorrection = "timezonecorr"
    case timeZoneOffset = "timezone_offset"
    case url = "self"
  }
}
