/// An extensible state, territory, or marine-area code accepted by NWS alert endpoints.
///
/// Named values match the live NWS schema. Unknown values remain available in ``rawValue``.
public struct AreaCode: Codable, CodingKeyRepresentable, Hashable, RawRepresentable, Sendable {
  // MARK: Land areas

  /// Alabama.
  public static let alabama = Self(rawValue: "AL")
  /// Alaska.
  public static let alaska = Self(rawValue: "AK")
  /// American Samoa.
  public static let americanSamoa = Self(rawValue: "AS")
  /// Arizona.
  public static let arizona = Self(rawValue: "AZ")
  /// Arkansas.
  public static let arkansas = Self(rawValue: "AR")
  /// California.
  public static let california = Self(rawValue: "CA")
  /// Colorado.
  public static let colorado = Self(rawValue: "CO")
  /// Connecticut.
  public static let connecticut = Self(rawValue: "CT")
  /// Delaware.
  public static let delaware = Self(rawValue: "DE")
  /// District of Columbia.
  public static let districtOfColumbia = Self(rawValue: "DC")
  /// Federated States of Micronesia.
  public static let federatedStatesOfMicronesia = Self(rawValue: "FM")
  /// Florida.
  public static let florida = Self(rawValue: "FL")
  /// Georgia.
  public static let georgia = Self(rawValue: "GA")
  /// Guam.
  public static let guam = Self(rawValue: "GU")
  /// Hawaii.
  public static let hawaii = Self(rawValue: "HI")
  /// Idaho.
  public static let idaho = Self(rawValue: "ID")
  /// Illinois.
  public static let illinois = Self(rawValue: "IL")
  /// Indiana.
  public static let indiana = Self(rawValue: "IN")
  /// Iowa.
  public static let iowa = Self(rawValue: "IA")
  /// Kansas.
  public static let kansas = Self(rawValue: "KS")
  /// Kentucky.
  public static let kentucky = Self(rawValue: "KY")
  /// Louisiana.
  public static let louisiana = Self(rawValue: "LA")
  /// Maine.
  public static let maine = Self(rawValue: "ME")
  /// Marshall Islands.
  public static let marshallIslands = Self(rawValue: "MH")
  /// Maryland.
  public static let maryland = Self(rawValue: "MD")
  /// Massachusetts.
  public static let massachusetts = Self(rawValue: "MA")
  /// Michigan.
  public static let michigan = Self(rawValue: "MI")
  /// Minnesota.
  public static let minnesota = Self(rawValue: "MN")
  /// Mississippi.
  public static let mississippi = Self(rawValue: "MS")
  /// Missouri.
  public static let missouri = Self(rawValue: "MO")
  /// Montana.
  public static let montana = Self(rawValue: "MT")
  /// Nebraska.
  public static let nebraska = Self(rawValue: "NE")
  /// Nevada.
  public static let nevada = Self(rawValue: "NV")
  /// New Hampshire.
  public static let newHampshire = Self(rawValue: "NH")
  /// New Jersey.
  public static let newJersey = Self(rawValue: "NJ")
  /// New Mexico.
  public static let newMexico = Self(rawValue: "NM")
  /// New York.
  public static let newYork = Self(rawValue: "NY")
  /// North Carolina.
  public static let northCarolina = Self(rawValue: "NC")
  /// North Dakota.
  public static let northDakota = Self(rawValue: "ND")
  /// Northern Mariana Islands.
  public static let northernMarianaIslands = Self(rawValue: "MP")
  /// Ohio.
  public static let ohio = Self(rawValue: "OH")
  /// Oklahoma.
  public static let oklahoma = Self(rawValue: "OK")
  /// Oregon.
  public static let oregon = Self(rawValue: "OR")
  /// Palau.
  public static let palau = Self(rawValue: "PW")
  /// Pennsylvania.
  public static let pennsylvania = Self(rawValue: "PA")
  /// Puerto Rico.
  public static let puertoRico = Self(rawValue: "PR")
  /// Rhode Island.
  public static let rhodeIsland = Self(rawValue: "RI")
  /// South Carolina.
  public static let southCarolina = Self(rawValue: "SC")
  /// South Dakota.
  public static let southDakota = Self(rawValue: "SD")
  /// Tennessee.
  public static let tennessee = Self(rawValue: "TN")
  /// Texas.
  public static let texas = Self(rawValue: "TX")
  /// United States Virgin Islands.
  public static let unitedStatesVirginIslands = Self(rawValue: "VI")
  /// Utah.
  public static let utah = Self(rawValue: "UT")
  /// Vermont.
  public static let vermont = Self(rawValue: "VT")
  /// Virginia.
  public static let virginia = Self(rawValue: "VA")
  /// Washington.
  public static let washington = Self(rawValue: "WA")
  /// West Virginia.
  public static let westVirginia = Self(rawValue: "WV")
  /// Wisconsin.
  public static let wisconsin = Self(rawValue: "WI")
  /// Wyoming.
  public static let wyoming = Self(rawValue: "WY")

  // MARK: Marine areas

  /// The central Pacific Ocean.
  public static let centralPacificOcean = Self(rawValue: "PH")
  /// The eastern North Pacific Ocean.
  public static let easternNorthPacificOcean = Self(rawValue: "PZ")
  /// The Gulf of Mexico.
  public static let gulfOfMexico = Self(rawValue: "GM")
  /// Lake Erie.
  public static let lakeErie = Self(rawValue: "LE")
  /// Lake Huron.
  public static let lakeHuron = Self(rawValue: "LH")
  /// Lake Michigan.
  public static let lakeMichigan = Self(rawValue: "LM")
  /// Lake Ontario.
  public static let lakeOntario = Self(rawValue: "LO")
  /// Lake St. Clair.
  public static let lakeStClair = Self(rawValue: "LC")
  /// Lake Superior.
  public static let lakeSuperior = Self(rawValue: "LS")
  /// The North Pacific Ocean near Alaska.
  public static let northPacificOceanNearAlaska = Self(rawValue: "PK")
  /// The northwest North Atlantic Ocean.
  public static let northwestNorthAtlanticOcean = Self(rawValue: "AN")
  /// The south-central Pacific Ocean.
  public static let southCentralPacificOcean = Self(rawValue: "PS")
  /// The St. Lawrence River.
  public static let stLawrenceRiver = Self(rawValue: "SL")
  /// The western North Atlantic Ocean.
  public static let westernNorthAtlanticOcean = Self(rawValue: "AM")
  /// The western Pacific Ocean.
  public static let westernPacificOcean = Self(rawValue: "PM")

  /// The service's exact code, used as the key when a code keys a JSON object.
  public var codingKey: any CodingKey { Key(stringValue: rawValue) }

  /// The service's exact code.
  public let rawValue: String

  /// Creates a code from a consumer-defined String-backed value.
  public init<Value>(_ value: Value) where Value: RawRepresentable, Value.RawValue == String {
    self.init(rawValue: value.rawValue)
  }

  /// Creates a code from a JSON object key; every key is accepted as an exact service code.
  /// - Parameter codingKey: The key whose string value is the service's code.
  public init?<T: CodingKey>(codingKey: T) {
    self.init(rawValue: codingKey.stringValue)
  }

  /// Creates a code without restricting future service values.
  public init(rawValue: String) { self.rawValue = rawValue }

  /// Decodes the exact service code.
  public init(from decoder: any Decoder) throws {
    rawValue = try decoder.singleValueContainer().decode(String.self)
  }

  /// Encodes the exact service code.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }

  private struct Key: CodingKey {
    var intValue: Int? { nil }
    let stringValue: String

    init(stringValue: String) { self.stringValue = stringValue }

    init?(intValue: Int) { nil }
  }
}
