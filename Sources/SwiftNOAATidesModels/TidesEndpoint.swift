#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A single JSON operation on the HTTPS CO-OPS origin.
///
/// Paths are immutable and validated. Use `TidesEndpoint<MyResponse>(path:)` for custom responses.
public struct TidesEndpoint<Response>: Hashable, Sendable {
  /// The exact encoded path and query relative to the CO-OPS origin.
  public let path: String

  /// Creates an endpoint from an HTTPS CO-OPS link without credentials or a fragment.
  /// - Parameter link: The provider link. Only the default port is accepted.
  public init?(link: URL) {
    guard let components = URLComponents(url: link, resolvingAgainstBaseURL: false),
      components.scheme?.lowercased() == "https",
      components.host?.lowercased() == "api.tidesandcurrents.noaa.gov",
      components.port == nil || components.port == 443,
      components.user == nil, components.password == nil, components.fragment == nil
    else { return nil }
    self.init(
      path: components.percentEncodedPath + (components.percentEncodedQuery.map { "?" + $0 } ?? ""))
  }

  /// Creates an endpoint from an encoded absolute-path reference and optional query.
  /// Raw controls, malformed escapes, authority forms, backslashes, and dot segments are refused.
  /// - Parameter path: A path beginning with one slash, retained without normalization.
  public init?(path: String) {
    guard Self.isValidPath(path) else { return nil }
    self.path = path
  }

  package func decoding<Value>(_ type: Value.Type) -> TidesEndpoint<Value> {
    TidesEndpoint<Value>.builtIn(path: path)
  }

  static func builtIn(path: String) -> Self {
    guard let result = Self(path: path) else {
      preconditionFailure("Fixed routes and encoded validated query values form valid paths.")
    }
    return result
  }

  static func query(_ items: [URLQueryItem]) -> String {
    var components = URLComponents()
    components.queryItems = items
    return components.percentEncodedQuery.map { "?" + $0 } ?? ""
  }

  private static func decoded(_ value: String) -> String? {
    let bytes = Array(value.utf8)
    var decoded: [UInt8] = []
    var index = 0
    while index < bytes.count {
      if bytes[index] == 37 {
        guard index + 2 < bytes.count,
          let byte = UInt8(
            String(decoding: bytes[(index + 1)...(index + 2)], as: UTF8.self), radix: 16)
        else { return nil }
        decoded.append(byte)
        index += 3
      } else {
        decoded.append(bytes[index])
        index += 1
      }
    }
    return String(validating: decoded, as: UTF8.self)
  }

  private static func isValidPath(_ value: String) -> Bool {
    guard value.hasPrefix("/"), !value.hasPrefix("//") else { return false }
    let bytes = Array(value.utf8)
    var index = 0
    var inQuery = false
    while index < bytes.count {
      let byte = bytes[index]
      if byte == 63 { inQuery = true }
      let allowed =
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~!$&'()*+,;=:@/?%"
      guard allowed.utf8.contains(byte) || (inQuery && (byte == 91 || byte == 93)) else {
        return false
      }
      if byte == 37 {
        guard index + 2 < bytes.count,
          UInt8(String(UnicodeScalar(bytes[index + 1])), radix: 16) != nil,
          UInt8(String(UnicodeScalar(bytes[index + 2])), radix: 16) != nil
        else { return false }
        index += 3
      } else {
        index += 1
      }
    }
    let path = value.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)[0]
    guard let decoded = decoded(String(path)),
      !decoded.hasPrefix("//"),
      !decoded.unicodeScalars.contains(where: {
        $0.properties.generalCategory == .control || $0 == "\\"
      })
    else { return false }
    return !decoded.split(separator: "/").contains { $0 == "." || $0 == ".." }
  }
}

extension TidesEndpoint where Response == AirPressureResponse {
  /// Retrieves reported air pressure without metadata preflight.
  /// - Parameter query: Explicit cadence, GMT range, station and requested units.
  /// - Returns: One independently decodable JSON endpoint.
  public static func airPressureObservations(matching query: CoastalObservationQuery) -> Self {
    var items = [
      URLQueryItem(name: "begin_date", value: TidesDateRange.encoded(query.range.begin)),
      URLQueryItem(name: "end_date", value: TidesDateRange.encoded(query.range.end)),
      URLQueryItem(name: "format", value: "json"),
    ]
    if query.interval == .hourly { items.append(URLQueryItem(name: "interval", value: "h")) }
    items += [
      URLQueryItem(name: "product", value: "air_pressure"),
      URLQueryItem(name: "station", value: query.stationIdentifier.rawValue),
      URLQueryItem(name: "time_zone", value: "gmt"),
      URLQueryItem(name: "units", value: query.units.rawValue),
    ]
    return builtIn(path: "/api/prod/datagetter" + Self.query(items))
  }
}

extension TidesEndpoint where Response == AirTemperatureResponse {
  /// Retrieves reported air temperature without metadata preflight.
  /// - Parameter query: Explicit cadence, GMT range, station and requested units.
  /// - Returns: One independently decodable JSON endpoint.
  public static func airTemperatureObservations(matching query: CoastalObservationQuery) -> Self {
    var items = [
      URLQueryItem(name: "begin_date", value: TidesDateRange.encoded(query.range.begin)),
      URLQueryItem(name: "end_date", value: TidesDateRange.encoded(query.range.end)),
      URLQueryItem(name: "format", value: "json"),
    ]
    if query.interval == .hourly { items.append(URLQueryItem(name: "interval", value: "h")) }
    items += [
      URLQueryItem(name: "product", value: "air_temperature"),
      URLQueryItem(name: "station", value: query.stationIdentifier.rawValue),
      URLQueryItem(name: "time_zone", value: "gmt"),
      URLQueryItem(name: "units", value: query.units.rawValue),
    ]
    return builtIn(path: "/api/prod/datagetter" + Self.query(items))
  }
}

extension TidesEndpoint where Response == CoastalDatums {
  /// Retrieves a station's datum table with explicitly requested units.
  /// - Parameters:
  ///   - stationIdentifier: The validated station identifier.
  ///   - units: A nonempty provider unit-system code without controls.
  /// - Returns: One metadata endpoint, without conversion or linked-resource expansion.
  /// - Throws: `TidesQueryError.invalidUnits` for an empty code or control characters.
  public static func datums(stationIdentifier: CoastalStationIdentifier, units: TidesUnits)
    throws(TidesQueryError) -> Self
  {
    guard !units.rawValue.isEmpty,
      !units.rawValue.unicodeScalars.contains(where: { $0.properties.generalCategory == .control })
    else { throw .invalidUnits(units.rawValue) }
    return builtIn(
      path: "/mdapi/prod/webapi/stations/\(stationIdentifier.rawValue)/datums.json"
        + Self.query([URLQueryItem(name: "units", value: units.rawValue)]))
  }
}

extension TidesEndpoint where Response == CoastalNotices {
  /// Retrieves the station's notices without expanding linked resources.
  /// - Parameter stationIdentifier: The validated station identifier.
  /// - Returns: The provider's notices envelope.
  public static func notices(stationIdentifier: CoastalStationIdentifier) -> Self {
    builtIn(path: "/mdapi/prod/webapi/stations/\(stationIdentifier.rawValue)/notices.json")
  }
}

extension TidesEndpoint where Response == CoastalSensors {
  /// Retrieves a station's sensor table with explicitly requested units.
  /// - Parameters:
  ///   - stationIdentifier: The validated station identifier.
  ///   - units: A nonempty provider unit-system code without controls.
  /// - Returns: One metadata endpoint, without conversion or linked-resource expansion.
  /// - Throws: `TidesQueryError.invalidUnits` for an empty code or control characters.
  public static func sensors(stationIdentifier: CoastalStationIdentifier, units: TidesUnits)
    throws(TidesQueryError) -> Self
  {
    guard !units.rawValue.isEmpty,
      !units.rawValue.unicodeScalars.contains(where: { $0.properties.generalCategory == .control })
    else { throw .invalidUnits(units.rawValue) }
    return builtIn(
      path: "/mdapi/prod/webapi/stations/\(stationIdentifier.rawValue)/sensors.json"
        + Self.query([URLQueryItem(name: "units", value: units.rawValue)]))
  }
}

extension TidesEndpoint where Response == CoastalStations {
  /// Retrieves one station's complete detail envelope without unwrapping.
  /// - Parameter identifier: A validated identifier whose case is retained.
  /// - Returns: The station-detail endpoint.
  public static func station(identifier: CoastalStationIdentifier) -> Self {
    builtIn(path: "/mdapi/prod/webapi/stations/\(identifier.rawValue).json")
  }

  /// Retrieves one directory response without expanding station resources.
  /// - Parameter query: The directory type.
  /// - Returns: The directory endpoint.
  public static func stations(matching query: CoastalStationQuery) -> Self {
    builtIn(
      path: "/mdapi/prod/webapi/stations.json"
        + Self.query([
          URLQueryItem(name: "type", value: query.type.rawValue)
        ]))
  }
}

extension TidesEndpoint where Response == ConductivityResponse {
  /// Retrieves reported conductivity without metadata preflight.
  /// - Parameter query: Explicit cadence, GMT range, station and requested units.
  /// - Returns: One independently decodable JSON endpoint.
  public static func conductivityObservations(matching query: CoastalObservationQuery) -> Self {
    var items = [
      URLQueryItem(name: "begin_date", value: TidesDateRange.encoded(query.range.begin)),
      URLQueryItem(name: "end_date", value: TidesDateRange.encoded(query.range.end)),
      URLQueryItem(name: "format", value: "json"),
    ]
    if query.interval == .hourly { items.append(URLQueryItem(name: "interval", value: "h")) }
    items += [
      URLQueryItem(name: "product", value: "conductivity"),
      URLQueryItem(name: "station", value: query.stationIdentifier.rawValue),
      URLQueryItem(name: "time_zone", value: "gmt"),
      URLQueryItem(name: "units", value: query.units.rawValue),
    ]
    return builtIn(path: "/api/prod/datagetter" + Self.query(items))
  }
}

extension TidesEndpoint where Response == CurrentBins {
  /// Retrieves a station's bin table with explicitly requested units.
  /// - Parameters:
  ///   - stationIdentifier: The validated station identifier.
  ///   - units: A nonempty provider unit-system code without controls.
  /// - Returns: One metadata endpoint, without conversion or linked-resource expansion.
  /// - Throws: `TidesQueryError.invalidUnits` for an empty code or control characters.
  public static func currentBins(stationIdentifier: CoastalStationIdentifier, units: TidesUnits)
    throws(TidesQueryError) -> Self
  {
    guard !units.rawValue.isEmpty,
      !units.rawValue.unicodeScalars.contains(where: { $0.properties.generalCategory == .control })
    else { throw .invalidUnits(units.rawValue) }
    return builtIn(
      path: "/mdapi/prod/webapi/stations/\(stationIdentifier.rawValue)/bins.json"
        + Self.query([URLQueryItem(name: "units", value: units.rawValue)]))
  }
}

extension TidesEndpoint where Response == CurrentEventResponse {
  /// Retrieves predicted current events in GMT without station preflight.
  /// - Parameter query: The validated prediction query.
  /// - Returns: One endpoint whose wire response decodes without request context.
  public static func currentEvents(matching query: CurrentEventQuery) -> Self {
    var items = [URLQueryItem(name: "begin_date", value: TidesDateRange.encoded(query.range.begin))]
    if let bin = query.bin.queryValue { items.append(URLQueryItem(name: "bin", value: bin)) }
    items += [
      URLQueryItem(name: "end_date", value: TidesDateRange.encoded(query.range.end)),
      URLQueryItem(name: "format", value: "json"),
      URLQueryItem(name: "interval", value: "max_slack"),
      URLQueryItem(name: "product", value: "currents_predictions"),
      URLQueryItem(name: "station", value: query.stationIdentifier.rawValue),
      URLQueryItem(name: "time_zone", value: "gmt"),
      URLQueryItem(name: "units", value: query.units.rawValue),
      URLQueryItem(name: "vel_type", value: "default"),
    ]
    return builtIn(path: "/api/prod/datagetter" + Self.query(items))
  }
}

extension TidesEndpoint where Response == CurrentObservationResponse {
  /// Retrieves measured currents without metadata preflight or time-window splitting.
  /// - Parameter query: The validated GMT, bin and units selection.
  /// - Returns: One independently decodable Data API endpoint.
  public static func currentObservations(matching query: CurrentObservationQuery) -> Self {
    var items = [URLQueryItem(name: "begin_date", value: TidesDateRange.encoded(query.range.begin))]
    if let bin = query.bin.queryValue { items.append(URLQueryItem(name: "bin", value: bin)) }
    items += [
      URLQueryItem(name: "end_date", value: TidesDateRange.encoded(query.range.end)),
      URLQueryItem(name: "format", value: "json"),
      URLQueryItem(name: "product", value: "currents"),
      URLQueryItem(name: "station", value: query.stationIdentifier.rawValue),
      URLQueryItem(name: "time_zone", value: "gmt"),
      URLQueryItem(name: "units", value: query.units.rawValue),
    ]
    return builtIn(path: "/api/prod/datagetter" + Self.query(items))
  }
}

extension TidesEndpoint where Response == CurrentPredictionResponse {
  /// Retrieves predicted current samples in GMT without station preflight.
  /// - Parameter query: The validated prediction query.
  /// - Returns: One endpoint whose wire response decodes without request context.
  public static func currentPredictions(matching query: CurrentPredictionQuery) -> Self {
    var items = [URLQueryItem(name: "begin_date", value: TidesDateRange.encoded(query.range.begin))]
    if let bin = query.bin.queryValue { items.append(URLQueryItem(name: "bin", value: bin)) }
    items += [
      URLQueryItem(name: "end_date", value: TidesDateRange.encoded(query.range.end)),
      URLQueryItem(name: "format", value: "json"),
      URLQueryItem(name: "interval", value: String(query.interval.rawValue)),
      URLQueryItem(name: "product", value: "currents_predictions"),
      URLQueryItem(name: "station", value: query.stationIdentifier.rawValue),
      URLQueryItem(name: "time_zone", value: "gmt"),
      URLQueryItem(name: "units", value: query.units.rawValue),
      URLQueryItem(name: "vel_type", value: query.mode.rawValue),
    ]
    return builtIn(path: "/api/prod/datagetter" + Self.query(items))
  }
}

extension TidesEndpoint where Response == HighLowTideResponse {
  /// Retrieves predicted high/low events as an independent wire envelope.
  /// - Parameter query: A validated explicit GMT query.
  /// - Returns: One JSON endpoint, with no station preflight or date-window splitting.
  public static func highLowTides(matching query: HighLowTideQuery) -> Self {
    builtIn(
      path: "/api/prod/datagetter"
        + Self.query([
          URLQueryItem(name: "begin_date", value: TidesDateRange.encoded(query.range.begin)),
          URLQueryItem(name: "datum", value: query.datum.rawValue),
          URLQueryItem(name: "end_date", value: TidesDateRange.encoded(query.range.end)),
          URLQueryItem(name: "format", value: "json"),
          URLQueryItem(name: "interval", value: "hilo"),
          URLQueryItem(name: "product", value: "predictions"),
          URLQueryItem(name: "station", value: query.stationIdentifier.rawValue),
          URLQueryItem(name: "time_zone", value: "gmt"),
          URLQueryItem(name: "units", value: query.units.rawValue),
        ]))
  }
}

extension TidesEndpoint where Response == HourlyWaterLevelResponse {
  /// Retrieves verified hourly heights as an independent wire envelope.
  /// - Parameter query: A validated explicit GMT query.
  /// - Returns: One JSON endpoint, with no station preflight or date-window splitting.
  public static func hourlyWaterLevels(matching query: HourlyWaterLevelQuery) -> Self {
    builtIn(
      path: "/api/prod/datagetter"
        + Self.query([
          URLQueryItem(name: "begin_date", value: TidesDateRange.encoded(query.range.begin)),
          URLQueryItem(name: "datum", value: query.datum.rawValue),
          URLQueryItem(name: "end_date", value: TidesDateRange.encoded(query.range.end)),
          URLQueryItem(name: "format", value: "json"),
          URLQueryItem(name: "product", value: "hourly_height"),
          URLQueryItem(name: "station", value: query.stationIdentifier.rawValue),
          URLQueryItem(name: "time_zone", value: "gmt"),
          URLQueryItem(name: "units", value: query.units.rawValue),
        ]))
  }
}

extension TidesEndpoint where Response == HumidityResponse {
  /// Retrieves reported humidity without metadata preflight.
  /// - Parameter query: Explicit cadence, GMT range, station and requested units.
  /// - Returns: One independently decodable JSON endpoint.
  public static func humidityObservations(matching query: CoastalObservationQuery) -> Self {
    var items = [
      URLQueryItem(name: "begin_date", value: TidesDateRange.encoded(query.range.begin)),
      URLQueryItem(name: "end_date", value: TidesDateRange.encoded(query.range.end)),
      URLQueryItem(name: "format", value: "json"),
    ]
    if query.interval == .hourly { items.append(URLQueryItem(name: "interval", value: "h")) }
    items += [
      URLQueryItem(name: "product", value: "humidity"),
      URLQueryItem(name: "station", value: query.stationIdentifier.rawValue),
      URLQueryItem(name: "time_zone", value: "gmt"),
      URLQueryItem(name: "units", value: query.units.rawValue),
    ]
    return builtIn(path: "/api/prod/datagetter" + Self.query(items))
  }
}

extension TidesEndpoint where Response == SalinityResponse {
  /// Retrieves reported salinity without metadata preflight.
  /// - Parameter query: Explicit cadence, GMT range, station and requested units.
  /// - Returns: One independently decodable JSON endpoint.
  public static func salinityObservations(matching query: CoastalObservationQuery) -> Self {
    var items = [
      URLQueryItem(name: "begin_date", value: TidesDateRange.encoded(query.range.begin)),
      URLQueryItem(name: "end_date", value: TidesDateRange.encoded(query.range.end)),
      URLQueryItem(name: "format", value: "json"),
    ]
    if query.interval == .hourly { items.append(URLQueryItem(name: "interval", value: "h")) }
    items += [
      URLQueryItem(name: "product", value: "salinity"),
      URLQueryItem(name: "station", value: query.stationIdentifier.rawValue),
      URLQueryItem(name: "time_zone", value: "gmt"),
      URLQueryItem(name: "units", value: query.units.rawValue),
    ]
    return builtIn(path: "/api/prod/datagetter" + Self.query(items))
  }
}

extension TidesEndpoint where Response == TidePredictionResponse {
  /// Retrieves predicted tide samples as an independent wire envelope.
  /// - Parameter query: A validated explicit GMT query.
  /// - Returns: One JSON endpoint, with no station preflight or date-window splitting.
  public static func tidePredictions(matching query: TidePredictionQuery) -> Self {
    builtIn(
      path: "/api/prod/datagetter"
        + Self.query([
          URLQueryItem(name: "begin_date", value: TidesDateRange.encoded(query.range.begin)),
          URLQueryItem(name: "datum", value: query.datum.rawValue),
          URLQueryItem(name: "end_date", value: TidesDateRange.encoded(query.range.end)),
          URLQueryItem(name: "format", value: "json"),
          URLQueryItem(name: "interval", value: String(query.interval.rawValue)),
          URLQueryItem(name: "product", value: "predictions"),
          URLQueryItem(name: "station", value: query.stationIdentifier.rawValue),
          URLQueryItem(name: "time_zone", value: "gmt"),
          URLQueryItem(name: "units", value: query.units.rawValue),
        ]))
  }
}

extension TidesEndpoint where Response == VisibilityResponse {
  /// Retrieves reported visibility without metadata preflight.
  /// - Parameter query: Explicit cadence, GMT range, station and requested units.
  /// - Returns: One independently decodable JSON endpoint.
  public static func visibilityObservations(matching query: CoastalObservationQuery) -> Self {
    var items = [
      URLQueryItem(name: "begin_date", value: TidesDateRange.encoded(query.range.begin)),
      URLQueryItem(name: "end_date", value: TidesDateRange.encoded(query.range.end)),
      URLQueryItem(name: "format", value: "json"),
    ]
    if query.interval == .hourly { items.append(URLQueryItem(name: "interval", value: "h")) }
    items += [
      URLQueryItem(name: "product", value: "visibility"),
      URLQueryItem(name: "station", value: query.stationIdentifier.rawValue),
      URLQueryItem(name: "time_zone", value: "gmt"),
      URLQueryItem(name: "units", value: query.units.rawValue),
    ]
    return builtIn(path: "/api/prod/datagetter" + Self.query(items))
  }
}

extension TidesEndpoint where Response == WaterLevelResponse {
  /// Retrieves measured six-minute water levels as an independent wire envelope.
  /// - Parameter query: A validated explicit GMT query.
  /// - Returns: One JSON endpoint, with no station preflight or date-window splitting.
  public static func waterLevels(matching query: WaterLevelQuery) -> Self {
    builtIn(
      path: "/api/prod/datagetter"
        + Self.query([
          URLQueryItem(name: "begin_date", value: TidesDateRange.encoded(query.range.begin)),
          URLQueryItem(name: "datum", value: query.datum.rawValue),
          URLQueryItem(name: "end_date", value: TidesDateRange.encoded(query.range.end)),
          URLQueryItem(name: "format", value: "json"),
          URLQueryItem(name: "product", value: "water_level"),
          URLQueryItem(name: "station", value: query.stationIdentifier.rawValue),
          URLQueryItem(name: "time_zone", value: "gmt"),
          URLQueryItem(name: "units", value: query.units.rawValue),
        ]))
  }
}

extension TidesEndpoint where Response == WaterTemperatureResponse {
  /// Retrieves reported water temperature without metadata preflight.
  /// - Parameter query: Explicit cadence, GMT range, station and requested units.
  /// - Returns: One independently decodable JSON endpoint.
  public static func waterTemperatureObservations(matching query: CoastalObservationQuery) -> Self {
    var items = [
      URLQueryItem(name: "begin_date", value: TidesDateRange.encoded(query.range.begin)),
      URLQueryItem(name: "end_date", value: TidesDateRange.encoded(query.range.end)),
      URLQueryItem(name: "format", value: "json"),
    ]
    if query.interval == .hourly { items.append(URLQueryItem(name: "interval", value: "h")) }
    items += [
      URLQueryItem(name: "product", value: "water_temperature"),
      URLQueryItem(name: "station", value: query.stationIdentifier.rawValue),
      URLQueryItem(name: "time_zone", value: "gmt"),
      URLQueryItem(name: "units", value: query.units.rawValue),
    ]
    return builtIn(path: "/api/prod/datagetter" + Self.query(items))
  }
}

extension TidesEndpoint where Response == WindResponse {
  /// Retrieves reported wind without metadata preflight.
  /// - Parameter query: Explicit cadence, GMT range, station and requested units.
  /// - Returns: One independently decodable JSON endpoint.
  public static func windObservations(matching query: CoastalObservationQuery) -> Self {
    var items = [
      URLQueryItem(name: "begin_date", value: TidesDateRange.encoded(query.range.begin)),
      URLQueryItem(name: "end_date", value: TidesDateRange.encoded(query.range.end)),
      URLQueryItem(name: "format", value: "json"),
    ]
    if query.interval == .hourly { items.append(URLQueryItem(name: "interval", value: "h")) }
    items += [
      URLQueryItem(name: "product", value: "wind"),
      URLQueryItem(name: "station", value: query.stationIdentifier.rawValue),
      URLQueryItem(name: "time_zone", value: "gmt"),
      URLQueryItem(name: "units", value: query.units.rawValue),
    ]
    return builtIn(path: "/api/prod/datagetter" + Self.query(items))
  }
}
