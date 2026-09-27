/// A reusable description of a CO-OPS operation, with no I/O or transport dependency.
public struct TidesRequest<Response>: Hashable, Sendable {
  /// The portable work needed to obtain the response.
  public enum Resolution: Hashable, Sendable {
    /// Attaches requested context to air pressure observations.
    case airPressureObservations(CoastalObservationQuery)
    /// Attaches requested context to air temperature observations.
    case airTemperatureObservations(CoastalObservationQuery)
    /// Attaches requested context to conductivity observations.
    case conductivityObservations(CoastalObservationQuery)
    /// Attach requested context to predicted current events.
    case currentEvents(CurrentEventQuery)
    /// Attach requested bin, units and range to measured currents.
    case currentObservations(CurrentObservationQuery)
    /// Attach requested context to predicted current samples.
    case currentPredictions(CurrentPredictionQuery)
    /// Decode a single endpoint directly as Response.
    case endpoint(TidesEndpoint<Response>)
    /// Attach requested context to predicted high/low events.
    case highLowTides(HighLowTideQuery)
    /// Attach requested context to verified hourly heights.
    case hourlyWaterLevels(HourlyWaterLevelQuery)
    /// Attaches requested context to humidity observations.
    case humidityObservations(CoastalObservationQuery)
    /// Validates latest-reading cardinality and attaches requested context.
    case latestWaterLevel(LatestWaterLevelQuery)
    /// Attaches requested context to provider-verified observed extrema.
    case observedHighLowWaterLevels(ObservedHighLowWaterLevelQuery)
    /// Attaches requested context to preliminary one-minute levels.
    case oneMinuteWaterLevels(OneMinuteWaterLevelQuery)
    /// Attaches requested context to salinity observations.
    case salinityObservations(CoastalObservationQuery)
    /// Require exactly one matching station from its detail envelope.
    case station(CoastalStationIdentifier)
    /// Attach requested context to sampled tide predictions.
    case tidePredictions(TidePredictionQuery)
    /// Attaches requested context to visibility observations.
    case visibilityObservations(CoastalObservationQuery)
    /// Attach requested context to measured six-minute water levels.
    case waterLevels(WaterLevelQuery)
    /// Attaches requested context to water temperature observations.
    case waterTemperatureObservations(CoastalObservationQuery)
    /// Attaches requested context to wind observations.
    case windObservations(CoastalObservationQuery)
  }

  /// The work an executor interprets.
  public let resolution: Resolution

  private init(resolution: Resolution) { self.resolution = resolution }
}

extension TidesRequest where Response: Decodable {
  /// Creates a request for a consumer-defined or built-in single endpoint.
  /// - Parameter endpoint: The endpoint whose body decodes as Response.
  public init(endpoint: TidesEndpoint<Response>) {
    self.resolution = .endpoint(endpoint)
  }
}

extension TidesRequest where Response == AirPressureObservations {
  /// Describes air pressure with separate requested context.
  /// - Parameter query: The validated observation query.
  /// - Returns: An immutable request that performs no I/O.
  public static func airPressureObservations(matching query: CoastalObservationQuery) -> Self {
    Self(resolution: .airPressureObservations(query))
  }
}

extension TidesRequest where Response == AirTemperatureObservations {
  /// Describes air temperature with separate requested context.
  /// - Parameter query: The validated observation query.
  /// - Returns: An immutable request that performs no I/O.
  public static func airTemperatureObservations(matching query: CoastalObservationQuery) -> Self {
    Self(resolution: .airTemperatureObservations(query))
  }
}

extension TidesRequest where Response == CoastalDatums {
  /// Describes a station datum-table request without conversion.
  /// - Parameters:
  ///   - stationIdentifier: The validated station identifier.
  ///   - units: The requested metadata unit-system code.
  /// - Returns: A reusable single-endpoint request.
  /// - Throws: `TidesQueryError.invalidUnits` for an empty code or control characters.
  public static func datums(stationIdentifier: CoastalStationIdentifier, units: TidesUnits)
    throws(TidesQueryError) -> Self
  {
    Self(endpoint: try .datums(stationIdentifier: stationIdentifier, units: units))
  }
}

extension TidesRequest where Response == CoastalFloodLevels {
  /// Retrieves raw flood thresholds without expanding linked resources.
  /// - Parameter stationIdentifier: The validated station identifier.
  /// - Parameter units: Requested threshold units; the body does not echo its units or datum.
  /// - Returns: The provider's raw threshold metadata.
  /// - Throws: `TidesQueryError.invalidUnits` for empty or control-containing units.
  public static func floodLevels(stationIdentifier: CoastalStationIdentifier, units: TidesUnits)
    throws(TidesQueryError) -> Self
  {
    Self(endpoint: try .floodLevels(stationIdentifier: stationIdentifier, units: units))
  }
}

extension TidesRequest where Response == CoastalNotices {
  /// Retrieves the station's notices without expanding linked resources.
  /// - Parameter stationIdentifier: The validated station identifier.
  /// - Returns: The provider's notices envelope.
  public static func notices(stationIdentifier: CoastalStationIdentifier) -> Self {
    Self(endpoint: .notices(stationIdentifier: stationIdentifier))
  }
}

extension TidesRequest where Response == CoastalSensors {
  /// Retrieves the station's sensors without expanding linked resources.
  /// - Parameter stationIdentifier: The validated station identifier.
  /// - Parameter units: Requested elevation units; the response retains reported units.
  /// - Returns: The provider's sensors envelope.
  /// - Throws: `TidesQueryError.invalidUnits` for empty or control-containing units.
  public static func sensors(stationIdentifier: CoastalStationIdentifier, units: TidesUnits)
    throws(TidesQueryError) -> Self
  {
    Self(endpoint: try .sensors(stationIdentifier: stationIdentifier, units: units))
  }
}

extension TidesRequest where Response == CoastalStation {
  /// Describes a detail lookup that requires one matching station.
  /// - Parameter identifier: A validated provider identifier.
  /// - Returns: A request that unwraps only a single matching station.
  public static func station(identifier: CoastalStationIdentifier) -> Self {
    Self(resolution: .station(identifier))
  }
}

extension TidesRequest where Response == CoastalStations {
  /// Describes one directory response in provider order.
  /// - Parameter query: The validated station category.
  /// - Returns: A request that keeps the directory envelope.
  public static func stations(matching query: CoastalStationQuery) -> Self {
    Self(endpoint: .stations(matching: query))
  }
}

extension TidesRequest where Response == ConductivityObservations {
  /// Describes conductivity with separate requested context.
  /// - Parameter query: The validated observation query.
  /// - Returns: An immutable request that performs no I/O.
  public static func conductivityObservations(matching query: CoastalObservationQuery) -> Self {
    Self(resolution: .conductivityObservations(query))
  }
}

extension TidesRequest where Response == CurrentBins {
  /// Describes a station bin-table request without conversion.
  /// - Parameters:
  ///   - stationIdentifier: The validated station identifier.
  ///   - units: The requested metadata unit-system code.
  /// - Returns: A reusable single-endpoint request.
  /// - Throws: `TidesQueryError.invalidUnits` for an empty code or control characters.
  public static func currentBins(stationIdentifier: CoastalStationIdentifier, units: TidesUnits)
    throws(TidesQueryError) -> Self
  {
    Self(endpoint: try .currentBins(stationIdentifier: stationIdentifier, units: units))
  }
}

extension TidesRequest where Response == CurrentEvents {
  /// Describes predicted current events with separate requested context.
  /// - Parameter query: The validated prediction query.
  /// - Returns: A reusable request that performs no I/O at construction.
  public static func currentEvents(matching query: CurrentEventQuery) -> Self {
    Self(resolution: .currentEvents(query))
  }
}

extension TidesRequest where Response == CurrentObservations {
  /// Describes measured currents with separate requested context.
  /// - Parameter query: The validated bin, GMT range and units selection.
  /// - Returns: An inspectable request with no I/O.
  public static func currentObservations(matching query: CurrentObservationQuery) -> Self {
    Self(resolution: .currentObservations(query))
  }
}

extension TidesRequest where Response == CurrentPredictions {
  /// Describes predicted current samples with separate requested context.
  /// - Parameter query: The validated prediction query.
  /// - Returns: A reusable request that performs no I/O at construction.
  public static func currentPredictions(matching query: CurrentPredictionQuery) -> Self {
    Self(resolution: .currentPredictions(query))
  }
}

extension TidesRequest where Response == HighLowTides {
  /// Describes high/low predictions with immutable requested context.
  /// - Parameter query: The validated explicit GMT query.
  /// - Returns: A reusable request that attaches context after direct wire decoding.
  public static func highLowTides(matching query: HighLowTideQuery) -> Self {
    Self(resolution: .highLowTides(query))
  }
}

extension TidesRequest where Response == HourlyWaterLevels {
  /// Describes verified hourly heights with immutable requested context.
  /// - Parameter query: The validated explicit GMT query.
  /// - Returns: A reusable request that attaches context after direct wire decoding.
  public static func hourlyWaterLevels(matching query: HourlyWaterLevelQuery) -> Self {
    Self(resolution: .hourlyWaterLevels(query))
  }
}

extension TidesRequest where Response == HumidityObservations {
  /// Describes humidity with separate requested context.
  /// - Parameter query: The validated observation query.
  /// - Returns: An immutable request that performs no I/O.
  public static func humidityObservations(matching query: CoastalObservationQuery) -> Self {
    Self(resolution: .humidityObservations(query))
  }
}

extension TidesRequest where Response == LatestWaterLevel {
  /// Describes a latest reading without evaluating a clock or performing I/O.
  /// - Parameter query: Explicit station, datum and units.
  /// - Returns: A reusable latest request; each execution can return a different reading.
  public static func latestWaterLevel(matching query: LatestWaterLevelQuery) -> Self {
    Self(resolution: .latestWaterLevel(query))
  }
}

extension TidesRequest where Response == ObservedHighLowWaterLevels {
  /// Describes observed high/low levels without performing I/O.
  /// - Parameter query: The validated observed high/low query.
  /// - Returns: An immutable reusable request.
  public static func observedHighLowWaterLevels(matching query: ObservedHighLowWaterLevelQuery)
    -> Self
  {
    Self(resolution: .observedHighLowWaterLevels(query))
  }
}

extension TidesRequest where Response == OneMinuteWaterLevels {
  /// Describes one-minute levels without performing I/O.
  /// - Parameter query: The validated one-minute query.
  /// - Returns: An immutable reusable request.
  public static func oneMinuteWaterLevels(matching query: OneMinuteWaterLevelQuery) -> Self {
    Self(resolution: .oneMinuteWaterLevels(query))
  }
}

extension TidesRequest where Response == SalinityObservations {
  /// Describes salinity with separate requested context.
  /// - Parameter query: The validated observation query.
  /// - Returns: An immutable request that performs no I/O.
  public static func salinityObservations(matching query: CoastalObservationQuery) -> Self {
    Self(resolution: .salinityObservations(query))
  }
}

extension TidesRequest where Response == TidePredictions {
  /// Describes sampled tide predictions with immutable requested context.
  /// - Parameter query: The validated explicit GMT query.
  /// - Returns: A reusable request that attaches context after direct wire decoding.
  public static func tidePredictions(matching query: TidePredictionQuery) -> Self {
    Self(resolution: .tidePredictions(query))
  }
}

extension TidesRequest where Response == VisibilityObservations {
  /// Describes visibility with separate requested context.
  /// - Parameter query: The validated observation query.
  /// - Returns: An immutable request that performs no I/O.
  public static func visibilityObservations(matching query: CoastalObservationQuery) -> Self {
    Self(resolution: .visibilityObservations(query))
  }
}

extension TidesRequest where Response == WaterLevels {
  /// Describes six-minute measurements with immutable requested context.
  /// - Parameter query: The validated explicit GMT query.
  /// - Returns: A reusable request that attaches context after direct wire decoding.
  public static func waterLevels(matching query: WaterLevelQuery) -> Self {
    Self(resolution: .waterLevels(query))
  }
}

extension TidesRequest where Response == WaterTemperatureObservations {
  /// Describes water temperature with separate requested context.
  /// - Parameter query: The validated observation query.
  /// - Returns: An immutable request that performs no I/O.
  public static func waterTemperatureObservations(matching query: CoastalObservationQuery) -> Self {
    Self(resolution: .waterTemperatureObservations(query))
  }
}

extension TidesRequest where Response == WindObservations {
  /// Describes wind with separate requested context.
  /// - Parameter query: The validated observation query.
  /// - Returns: An immutable request that performs no I/O.
  public static func windObservations(matching query: CoastalObservationQuery) -> Self {
    Self(resolution: .windObservations(query))
  }
}
