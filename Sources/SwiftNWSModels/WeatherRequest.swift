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

    /// Retrieve a station-directory page, with continuation semantics in sequence executors.
    /// Only requests returning FeatureCollection<ObservationStation> carry this resolution.
    case observationStations(ObservationStationQuery)

    /// Retrieve an observation-history page, with continuation semantics in sequence executors.
    /// Only requests returning FeatureCollection<WeatherObservation> carry this resolution.
    case observations(ObservationQuery)
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

extension WeatherRequest where Response == FeatureCollection<ObservationStation> {
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
  /// - Returns: A reusable request for a GeoJSON collection.
  public static func activeAlerts(inArea area: AreaCode) -> Self {
    Self(resolution: .activeAlerts(.activeAlerts(inArea: area)))
  }

  /// Describes active alerts using a consumer-defined area enum.
  /// - Parameter area: A String-backed state, territory, or marine area code.
  /// - Returns: A reusable request for a GeoJSON collection.
  public static func activeAlerts<Area>(inArea area: Area) -> Self
  where Area: RawRepresentable, Area.RawValue == String {
    activeAlerts(inArea: AreaCode(area))
  }

  /// Describes active alerts in a marine region.
  /// - Parameter region: A marine region code.
  /// - Returns: A reusable request for a GeoJSON collection.
  public static func activeAlerts(inRegion region: MarineRegionCode) -> Self {
    Self(resolution: .activeAlerts(.activeAlerts(inRegion: region)))
  }

  /// Describes active alerts using a consumer-defined marine region enum.
  /// - Parameter region: A String-backed marine region code.
  /// - Returns: A reusable request for a GeoJSON collection.
  public static func activeAlerts<Region>(inRegion region: Region) -> Self
  where Region: RawRepresentable, Region.RawValue == String {
    activeAlerts(inRegion: MarineRegionCode(region))
  }

  /// Describes active alerts in a provider zone.
  /// - Parameter zone: A nonempty zone identifier.
  /// - Returns: A reusable request for a GeoJSON collection.
  public static func activeAlerts(inZone zone: String) -> Self {
    Self(resolution: .activeAlerts(.activeAlerts(inZone: zone)))
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
}
