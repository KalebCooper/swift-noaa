import Foundation
import Observation
import SwiftNOAATides
import SwiftNOAATidesModels

@MainActor
@Observable
final class TidesDemoModel {
  var day = Date.now
  var hourlyWater: HourlyWaterLevels?
  var isLoading = false
  var message: String?
  var result: HighLowTides?
  var samples: TidePredictions?
  var selectedStationIdentifier = ""
  var stations: [CoastalStation] = []
  var water: WaterLevels?

  private let client = TidesClient(configuration: .init(application: "SwiftNOAATidesDemo"))

  func loadHourlyWaterLevels() async {
    guard !isLoading else { return }
    isLoading = true
    message = nil
    hourlyWater = nil
    defer { isLoading = false }
    do {
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = .gmt
      let begin = calendar.startOfDay(for: day)
      guard let nextDay = calendar.date(byAdding: .day, value: 1, to: begin) else {
        message = "Choose a valid date."
        return
      }
      let range = try TidesDateRange(begin: begin, end: nextDay.addingTimeInterval(-60))
      let query = try HourlyWaterLevelQuery(
        datum: .meanLowerLowWater, range: range,
        stationIdentifier: CoastalStationIdentifier(selectedStationIdentifier), units: .metric)
      hourlyWater = try await client.hourlyWaterLevels(matching: query)
    } catch let error as TidesError {
      show(error)
    } catch {
      message = "Choose a station and a valid GMT date."
    }
  }

  func loadPredictions() async {
    guard !isLoading else { return }
    isLoading = true
    message = nil
    result = nil
    defer { isLoading = false }
    do {
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = .gmt
      let begin = calendar.startOfDay(for: day)
      guard let nextDay = calendar.date(byAdding: .day, value: 1, to: begin) else {
        message = "Choose a valid date."
        return
      }
      let range = try TidesDateRange(begin: begin, end: nextDay.addingTimeInterval(-60))
      let query = try HighLowTideQuery(
        datum: .meanLowerLowWater, range: range,
        stationIdentifier: CoastalStationIdentifier(selectedStationIdentifier), units: .metric)
      result = try await client.highLowTides(matching: query)
    } catch let error as TidesError {
      show(error)
    } catch {
      message = "Choose a station and a valid GMT date."
    }
  }

  func loadSamples() async {
    guard !isLoading else { return }
    isLoading = true
    message = nil
    samples = nil
    defer { isLoading = false }
    do {
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = .gmt
      let begin = calendar.startOfDay(for: day)
      guard let nextDay = calendar.date(byAdding: .day, value: 1, to: begin) else {
        message = "Choose a valid date."
        return
      }
      let range = try TidesDateRange(begin: begin, end: nextDay.addingTimeInterval(-60))
      let query = try TidePredictionQuery(
        datum: .meanLowerLowWater, interval: .hourly, range: range,
        stationIdentifier: CoastalStationIdentifier(selectedStationIdentifier), units: .metric)
      samples = try await client.tidePredictions(matching: query)
    } catch let error as TidesError {
      show(error)
    } catch {
      message = "Choose a station and a valid GMT date."
    }
  }

  func loadStations() async {
    guard !isLoading else { return }
    isLoading = true
    message = nil
    defer { isLoading = false }
    do {
      let query = try CoastalStationQuery(type: .tidePredictions)
      stations = try await client.stations(matching: query).stations
    } catch let error as TidesError {
      show(error)
    } catch {
      message = "Could not prepare the station directory."
    }
  }

  func loadWaterLevels() async {
    guard !isLoading else { return }
    isLoading = true
    message = nil
    water = nil
    defer { isLoading = false }
    do {
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = .gmt
      let begin = calendar.startOfDay(for: day)
      guard let nextDay = calendar.date(byAdding: .day, value: 1, to: begin) else {
        message = "Choose a valid date."
        return
      }
      let range = try TidesDateRange(begin: begin, end: nextDay.addingTimeInterval(-60))
      let query = try WaterLevelQuery(
        datum: .meanLowerLowWater, range: range,
        stationIdentifier: CoastalStationIdentifier(selectedStationIdentifier), units: .metric)
      water = try await client.waterLevels(matching: query)
    } catch let error as TidesError {
      show(error)
    } catch {
      message = "Choose a station and a valid GMT date."
    }
  }

  private func show(_ error: TidesError) {
    switch error {
    case .provider(let refusal): message = refusal.message
    case .transport(.cancelled): break
    default: message = "Could not load NOAA data. Please try again."
    }
  }
}
