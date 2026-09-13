#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The forecast grid and links for a latitude and longitude, from `/points/{latitude},{longitude}`.
///
/// A point is the first step of most lookups. It names the forecast office and grid cell that cover
/// the location and links to the forecasts and observation stations for it. Follow those links
/// rather than building their URLs, and keep the point: the mapping from a location to its grid
/// rarely changes.
///
/// ```swift
/// let point = try JSONDecoder().decode(Feature<Point>.self, from: body).properties
/// print(point.gridId, point.gridX, point.gridY)  // "EWX 156 91"
/// ```
public struct Point: Codable, Hashable, Sendable {
  /// The city and state nearest a point.
  public struct RelativeLocation: Codable, Hashable, Sendable {
    /// The name of the nearest city.
    public var city: String

    /// The two-letter abbreviation of the nearest city's state.
    public var state: String

    /// Creates a relative location.
    ///
    /// - Parameters:
    ///   - city: The name of the nearest city.
    ///   - state: The two-letter abbreviation of the state.
    public init(city: String, state: String) {
      self.city = city
      self.state = state
    }
  }

  /// The link to the twelve-hour forecast for the grid cell.
  public var forecast: URL

  /// The link to the raw forecast grid data for the grid cell.
  public var forecastGridData: URL

  /// The link to the hourly forecast for the grid cell.
  public var forecastHourly: URL

  /// The identifier of the forecast office whose grid covers the point, such as `EWX`.
  public var gridId: String

  /// The grid cell's column.
  public var gridX: Int

  /// The grid cell's row.
  public var gridY: Int

  /// The link to the observation stations near the grid cell, nearest first.
  public var observationStations: URL

  /// The city and state nearest the point.
  public var relativeLocation: Feature<RelativeLocation>?

  /// The IANA time zone identifier for the point, such as `America/Chicago`.
  public var timeZone: String

  /// Creates a point.
  ///
  /// - Parameters:
  ///   - forecast: The link to the twelve-hour forecast.
  ///   - forecastGridData: The link to the raw forecast grid data.
  ///   - forecastHourly: The link to the hourly forecast.
  ///   - gridId: The identifier of the forecast office.
  ///   - gridX: The grid cell's column.
  ///   - gridY: The grid cell's row.
  ///   - observationStations: The link to the nearby observation stations.
  ///   - relativeLocation: The city and state nearest the point.
  ///   - timeZone: The IANA time zone identifier.
  public init(
    forecast: URL,
    forecastGridData: URL,
    forecastHourly: URL,
    gridId: String,
    gridX: Int,
    gridY: Int,
    observationStations: URL,
    relativeLocation: Feature<RelativeLocation>? = nil,
    timeZone: String
  ) {
    self.forecast = forecast
    self.forecastGridData = forecastGridData
    self.forecastHourly = forecastHourly
    self.gridId = gridId
    self.gridX = gridX
    self.gridY = gridY
    self.observationStations = observationStations
    self.relativeLocation = relativeLocation
    self.timeZone = timeZone
  }
}
