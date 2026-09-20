#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A reusable, typed description of a weather lookup.
///
/// Creating a request performs no I/O. Inspect ``resolution`` to execute it with your own
/// networking stack, or pass it to `NWSClient.value(for:)` in SwiftNWS.
///
/// Add application vocabulary through constrained extensions. Use ``init(endpoint:)`` to
/// describe additional single-HTTP operations with your own response models.
public struct WeatherRequest<Response>: Hashable, Sendable {
  /// The transport-independent work required to obtain a request's response.
  public enum Resolution: Hashable, Sendable {
    /// Retrieve an active-alert page, with continuation semantics in sequence executors.
    /// Only requests returning FeatureCollection<WeatherAlert> carry this resolution.
    case activeAlerts(Endpoint<Response>)

    /// Retrieve an alert by identifier and return the GeoJSON properties.
    /// Only requests returning WeatherAlert carry this resolution.
    case alert(identifier: String)

    /// Retrieve an alert-history page, with continuation semantics in sequence executors.
    /// Only requests returning FeatureCollection<WeatherAlert> carry this resolution.
    case alerts(AlertQuery)

    /// Send one endpoint and decode its body directly as `Response`.
    case endpoint(Endpoint<Response>)

    /// Fetch a point, follow its forecast link with the options, and return the properties.
    /// Only requests returning WeatherForecast carry this resolution.
    case forecast(location: WeatherCoordinate, options: ForecastOptions)

    /// Fetch a point, follow its raw forecast grid data link, and return the properties.
    ///
    /// Only requests returning ``ForecastGrid`` carry this resolution. The grid request sends no
    /// units query or feature flags, and a disallowed link is a failure rather than a rebuilt path.
    case forecastGrid(location: WeatherCoordinate)

    /// Fetch a point, follow its hourly forecast link with the options, and return the properties.
    /// Only requests returning WeatherForecast carry this resolution.
    case hourlyForecast(location: WeatherCoordinate, options: ForecastOptions)

    /// Resolve the source and decode the latest observation's GeoJSON properties.
    ///
    /// Only requests whose response is ``WeatherObservation`` carry this resolution.
    /// For a coordinate, fetch its point, validate and follow its observation-stations link,
    /// and select the first station on the returned page. An empty list is a failure.
    /// Then fetch that station's latest observation. Do not fetch additional pages, filter
    /// by age, or try another station on failure.
    case latestObservation(ObservationSource)

    /// Fetch a point, follow its observation-stations link, and return that one page.
    ///
    /// Only requests returning FeatureCollection<ObservationStation> carry this resolution. The
    /// page's continuation link is never followed, in value or sequence execution: the service's
    /// link for this list names every station for the grid again at a later offset and leads only
    /// to empty pages.
    case nearbyObservationStations(location: WeatherCoordinate)

    /// Retrieve the observation a station made at an exact instant and return its GeoJSON
    /// properties.
    ///
    /// Only requests returning ``WeatherObservation`` carry this resolution. An empty identifier or invalid encoded path is
    /// a failure before any request. The instant must match an observation's timestamp; the service
    /// does not select the nearest observation, and no other instant or station is tried.
    case observation(stationIdentifier: String, timestamp: Date)

    /// Retrieve one station's metadata and return its GeoJSON properties.
    ///
    /// Only requests returning ``ObservationStation`` carry this resolution. An empty identifier or invalid encoded path is
    /// a failure before any request.
    case observationStation(identifier: String)

    /// Retrieve a station-directory page, with continuation semantics in sequence executors.
    /// Only requests returning FeatureCollection<ObservationStation> carry this resolution.
    case observationStations(ObservationStationQuery)

    /// Retrieve an observation-history page, with continuation semantics in sequence executors.
    /// Only requests returning FeatureCollection<WeatherObservation> carry this resolution.
    case observations(ObservationQuery)

    /// Retrieve one zone by type and identifier and return its GeoJSON properties.
    ///
    /// Only requests returning ``WeatherZone`` carry this resolution. An empty type or identifier,
    /// or one that produces an invalid encoded path, is a failure before any request. The
    /// feature's geometry is available only through the direct endpoint.
    case zone(effective: Date?, identifier: String, type: ZoneType)

    /// Retrieve the zones of one type matching a query as one response.
    ///
    /// Only requests returning FeatureCollection<WeatherZone> carry this resolution. An empty type
    /// or one that produces an invalid encoded path is a failure before any request. The service
    /// returns no continuation for the directory.
    case zonesOfType(query: ZoneQuery, type: ZoneType)
  }

  /// The description an executor interprets, without any SDK or transport dependency.
  public let resolution: Resolution

  /// Creates a request for a single endpoint, including a consumer-defined endpoint.
  ///
  /// - Parameter endpoint: The endpoint whose body decodes directly as `Response`.
  public init(endpoint: Endpoint<Response>) {
    self.resolution = .endpoint(endpoint)
  }

  private init(resolution: Resolution) {
    self.resolution = resolution
  }
}

extension WeatherRequest where Response == ObservationStation {
  /// Describes the metadata for one observation station.
  ///
  /// ```swift
  /// let request = WeatherRequest.observationStation(identifier: "KATT")
  /// ```
  ///
  /// - Parameter identifier: The station's identifier, such as `KATT`.
  /// - Returns: A reusable request returning the station's properties.
  public static func observationStation(identifier: String) -> Self {
    Self(resolution: .observationStation(identifier: identifier))
  }
}

extension WeatherRequest where Response == FeatureCollection<ObservationStation> {
  /// Describes the observation stations the service lists for a coordinate's grid cell.
  ///
  /// The list is one page in the service's order, which does not guarantee distance order.
  ///
  /// ```swift
  /// let request = WeatherRequest.observationStations(near: home)
  /// ```
  ///
  /// - Parameter location: The validated coordinate.
  /// - Returns: A reusable request; value and sequence execution both return one page.
  public static func observationStations(near location: WeatherCoordinate) -> Self {
    Self(resolution: .nearbyObservationStations(location: location))
  }

  /// Describes a station-directory query with optional continuation.
  /// - Parameter query: The validated filters and initial cursor.
  /// - Returns: A reusable request; value execution retrieves one page and sequence execution follows links.
  public static func observationStations(query: ObservationStationQuery) -> Self {
    Self(resolution: .observationStations(query))
  }
}

extension WeatherRequest where Response == FeatureCollection<WeatherObservation> {
  /// Describes an observation-history query with optional continuation.
  /// - Parameter query: The validated station, window, page size, and initial cursor.
  /// - Returns: A reusable request; value execution retrieves one page and sequence execution follows links.
  public static func observations(query: ObservationQuery) -> Self {
    Self(resolution: .observations(query))
  }
}

extension WeatherRequest where Response == FeatureCollection<WeatherAlert> {
  /// Describes active alerts at a coordinate.
  /// - Parameter location: The coordinate to filter.
  /// - Returns: A reusable request for a GeoJSON collection.
  public static func activeAlerts(for location: WeatherCoordinate) -> Self {
    Self(resolution: .activeAlerts(.activeAlerts(for: location)))
  }

  /// Describes active alerts in a provider area.
  /// - Parameter area: A state, territory, or marine area code.
  /// - Returns: A reusable request, or nil for an empty code or invalid encoded path.
  public static func activeAlerts(inArea area: AreaCode) -> Self? {
    guard let endpoint = Endpoint<FeatureCollection<WeatherAlert>>.activeAlerts(inArea: area) else {
      return nil
    }
    return Self(resolution: .activeAlerts(endpoint))
  }

  /// Describes active alerts using a consumer-defined area enum.
  /// - Parameter area: A String-backed state, territory, or marine area code.
  /// - Returns: A reusable request, or nil for an empty code or invalid encoded path.
  public static func activeAlerts<Area>(inArea area: Area) -> Self?
  where Area: RawRepresentable, Area.RawValue == String {
    activeAlerts(inArea: AreaCode(area))
  }

  /// Describes active alerts in a marine region.
  /// - Parameter region: A marine region code.
  /// - Returns: A reusable request, or nil for an empty code or invalid encoded path.
  public static func activeAlerts(inRegion region: MarineRegionCode) -> Self? {
    guard let endpoint = Endpoint<FeatureCollection<WeatherAlert>>.activeAlerts(inRegion: region)
    else {
      return nil
    }
    return Self(resolution: .activeAlerts(endpoint))
  }

  /// Describes active alerts using a consumer-defined marine region enum.
  /// - Parameter region: A String-backed marine region code.
  /// - Returns: A reusable request, or nil for an empty code or invalid encoded path.
  public static func activeAlerts<Region>(inRegion region: Region) -> Self?
  where Region: RawRepresentable, Region.RawValue == String {
    activeAlerts(inRegion: MarineRegionCode(region))
  }

  /// Describes active alerts in a provider zone.
  /// - Parameter zone: A nonempty zone identifier.
  /// - Returns: A reusable request, or nil for an empty code or invalid encoded path.
  public static func activeAlerts(inZone zone: String) -> Self? {
    guard let endpoint = Endpoint<FeatureCollection<WeatherAlert>>.activeAlerts(inZone: zone) else {
      return nil
    }
    return Self(resolution: .activeAlerts(endpoint))
  }

  /// Describes an active-alert query.
  /// - Parameter filter: The supported filters.
  /// - Returns: A reusable request for a GeoJSON collection.
  public static func activeAlerts(matching filter: ActiveAlertFilter = .init()) -> Self {
    Self(resolution: .activeAlerts(.activeAlerts(matching: filter)))
  }

  /// Describes an alert-history query with optional continuation.
  /// - Parameter query: The validated filters, window, page size, and initial cursor.
  /// - Returns: A reusable request; value execution retrieves one page and sequence execution follows links.
  public static func alerts(matching query: AlertQuery) -> Self {
    Self(resolution: .alerts(query))
  }
}

extension WeatherRequest where Response == ActiveAlertCount {
  /// Describes the count of active alerts by region type, marine region, area, and zone.
  ///
  /// The request sends ``Endpoint/activeAlertCount`` and returns its body unchanged.
  public static var activeAlertCount: Self {
    Self(endpoint: .activeAlertCount)
  }
}

extension WeatherRequest where Response == AlertTypes {
  /// Describes the list of alert event names the service recognizes.
  ///
  /// The request sends ``Endpoint/alertTypes`` and returns its body unchanged.
  public static var alertTypes: Self {
    Self(endpoint: .alertTypes)
  }
}

extension WeatherRequest where Response == WeatherAlert {
  /// Describes retrieval of one alert.
  /// - Parameter identifier: The provider alert identifier.
  /// - Returns: A reusable request returning the alert properties.
  public static func alert(identifier: String) -> Self {
    Self(resolution: .alert(identifier: identifier))
  }
}

extension WeatherRequest where Response == WeatherForecast {
  /// Describes the twelve-hour forecast for a coordinate.
  /// - Parameters:
  ///   - location: The validated coordinate.
  ///   - options: Units and representation flags.
  /// - Returns: A reusable request that performs no I/O at construction.
  public static func forecast(for location: WeatherCoordinate, options: ForecastOptions = .init())
    -> Self
  {
    Self(resolution: .forecast(location: location, options: options))
  }

  /// Describes the hourly forecast for a coordinate.
  /// - Parameters:
  ///   - location: The validated coordinate.
  ///   - options: Units and representation flags.
  /// - Returns: A reusable request that performs no I/O at construction.
  public static func hourlyForecast(
    for location: WeatherCoordinate, options: ForecastOptions = .init()
  ) -> Self {
    Self(resolution: .hourlyForecast(location: location, options: options))
  }
}

extension WeatherRequest where Response == ForecastGrid {
  /// Describes the raw forecast grid data for a coordinate.
  ///
  /// Executing the request resolves the coordinate's point and follows its grid data link. The
  /// grid is never cached; the point is, by the SDK's point cache.
  ///
  /// ```swift
  /// let request = WeatherRequest.forecastGrid(for: home)
  /// ```
  ///
  /// - Parameter location: The validated coordinate.
  /// - Returns: A reusable request that performs no I/O at construction.
  public static func forecastGrid(for location: WeatherCoordinate) -> Self {
    Self(resolution: .forecastGrid(location: location))
  }
}

extension WeatherRequest where Response == WeatherObservation {
  /// Describes the latest observation from an explicit station or a coordinate's station list.
  ///
  /// The result retains its station identifier and timestamp. No freshness policy or fallback
  /// is applied. ``ObservationSource/nearest(to:)`` uses the first station the service lists.
  ///
  /// - Parameter source: The station or coordinate to look up.
  /// - Returns: A request that performs no work until executed.
  public static func latestObservation(from source: ObservationSource) -> Self {
    Self(resolution: .latestObservation(source))
  }

  /// Describes the observation a station made at an exact instant.
  ///
  /// The instant must be an observation's timestamp, such as one from observation history. The
  /// service answers any other instant with `404` problem details rather than the nearest
  /// observation, and no fallback is applied.
  ///
  /// ```swift
  /// let request = WeatherRequest.observation(stationIdentifier: "KATT", timestamp: timestamp)
  /// ```
  ///
  /// - Parameters:
  ///   - stationIdentifier: The station's identifier, such as `KATT`.
  ///   - timestamp: The observation's exact timestamp, sent with whole-second precision.
  /// - Returns: A request that performs no work until executed.
  public static func observation(stationIdentifier: String, timestamp: Date) -> Self {
    Self(resolution: .observation(stationIdentifier: stationIdentifier, timestamp: timestamp))
  }
}

extension WeatherRequest where Response == FeatureCollection<WeatherZone> {
  /// Describes the zones of one type matching a query, `/zones/{type}`.
  ///
  /// Executing the request rejects an empty type before sending and returns the one response the
  /// service answers; the directory has no continuation.
  ///
  /// ```swift
  /// let request = WeatherRequest.zones(matching: query, ofType: .forecast)
  /// ```
  ///
  /// - Parameters:
  ///   - query: The validated filters.
  ///   - type: The route's zone type.
  /// - Returns: A reusable request that performs no I/O at construction.
  public static func zones(matching query: ZoneQuery, ofType type: ZoneType) -> Self {
    Self(resolution: .zonesOfType(query: query, type: type))
  }

  /// Describes the zones of one type using a consumer-defined zone type enum.
  /// - Parameters:
  ///   - query: The validated filters.
  ///   - type: A String-backed zone type.
  /// - Returns: A reusable request that performs no I/O at construction.
  public static func zones<Kind>(matching query: ZoneQuery, ofType type: Kind) -> Self
  where Kind: RawRepresentable, Kind.RawValue == String {
    zones(matching: query, ofType: ZoneType(type))
  }

  /// Describes the zones of every type matching a query, `/zones`.
  ///
  /// The request sends `Endpoint.zones(matching:types:)` and returns its one response unchanged;
  /// the directory has no continuation.
  ///
  /// ```swift
  /// let request = WeatherRequest.zones(matching: query, types: [.county, .fire])
  /// ```
  ///
  /// - Parameters:
  ///   - query: The validated filters.
  ///   - types: Zone types to include, or an empty array for every type.
  /// - Returns: A reusable request that performs no I/O at construction.
  public static func zones(matching query: ZoneQuery, types: [ZoneType] = []) -> Self {
    Self(endpoint: .zones(matching: query, types: types))
  }

  /// Describes the zones of every type using a consumer-defined zone type enum.
  /// - Parameters:
  ///   - query: The validated filters.
  ///   - types: String-backed zone types to include.
  /// - Returns: A reusable request that performs no I/O at construction.
  public static func zones<Kind>(matching query: ZoneQuery, types: [Kind]) -> Self
  where Kind: RawRepresentable, Kind.RawValue == String {
    zones(matching: query, types: types.map { ZoneType($0) })
  }
}

extension WeatherRequest where Response == WeatherZone {
  /// Describes one zone by type and identifier, `/zones/{type}/{zoneId}`.
  ///
  /// Executing the request rejects an empty type or identifier before sending and returns the
  /// zone's properties. The feature's geometry is available through the direct endpoint.
  ///
  /// ```swift
  /// let request = WeatherRequest.zone(identifier: "TXZ192", type: .forecast)
  /// ```
  ///
  /// - Parameters:
  ///   - effective: The instant the definition must be effective at, or nil for the current one.
  ///   - identifier: The zone's identifier, such as `TXZ192`.
  ///   - type: The route's zone type.
  /// - Returns: A reusable request that performs no I/O at construction.
  public static func zone(effective: Date? = nil, identifier: String, type: ZoneType) -> Self {
    Self(resolution: .zone(effective: effective, identifier: identifier, type: type))
  }

  /// Describes one zone using a consumer-defined zone type enum.
  /// - Parameters:
  ///   - effective: The instant the definition must be effective at, or nil for the current one.
  ///   - identifier: The zone's identifier.
  ///   - type: A String-backed zone type.
  /// - Returns: A reusable request that performs no I/O at construction.
  public static func zone<Kind>(effective: Date? = nil, identifier: String, type: Kind) -> Self
  where Kind: RawRepresentable, Kind.RawValue == String {
    zone(effective: effective, identifier: identifier, type: ZoneType(type))
  }
}
