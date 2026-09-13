import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("WeatherCoordinate", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct WeatherCoordinateTests {
  @Test("Boundary coordinates remain valid")
  func boundaryCoordinatesRemainValid() throws {
    let location = try WeatherCoordinate(latitude: -90, longitude: 180)
    #expect(location.latitude == -90)
    #expect(location.longitude == 180)
  }

  @Test(
    "Invalid latitudes are rejected before rounding",
    arguments: [Double.nan, .infinity, -.infinity, .greatestFiniteMagnitude, -90.00001, 90.00001])
  func invalidLatitudesAreRejectedBeforeRounding(latitude: Double) {
    #expect(throws: WeatherCoordinate.ValidationError.invalidLatitude) {
      try WeatherCoordinate(latitude: latitude, longitude: 0)
    }
  }

  @Test(
    "Invalid longitudes are rejected before rounding",
    arguments: [Double.nan, .infinity, -.infinity, .greatestFiniteMagnitude, -180.00001, 180.00001])
  func invalidLongitudesAreRejectedBeforeRounding(longitude: Double) {
    #expect(throws: WeatherCoordinate.ValidationError.invalidLongitude) {
      try WeatherCoordinate(latitude: 0, longitude: longitude)
    }
  }

  @Test("Normalization rounds to four places and removes negative zero")
  func normalizationRoundsToFourPlacesAndRemovesNegativeZero() throws {
    let location = try WeatherCoordinate(latitude: 30.26721, longitude: -97.74306)
    #expect(location.latitude == 30.2672)
    #expect(location.longitude == -97.7431)
    let zero = try WeatherCoordinate(latitude: -0.00004, longitude: -0.0)
    #expect(zero.latitude.sign == .plus)
    #expect(zero.longitude.sign == .plus)
  }
}
