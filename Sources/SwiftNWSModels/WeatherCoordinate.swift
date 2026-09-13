/// A geographic coordinate normalized to the precision accepted by the weather API.
///
/// Initialization rejects invalid values before rounding to four decimal places.
/// Values halfway between two rounded coordinates round away from zero.
public struct WeatherCoordinate: Hashable, Sendable {
  /// Why a geographic coordinate could not be created.
  public enum ValidationError: Error {
    /// Latitude is nonfinite or outside -90 through 90 degrees.
    case invalidLatitude

    /// Longitude is nonfinite or outside -180 through 180 degrees.
    case invalidLongitude
  }

  /// The latitude in decimal degrees, rounded to four decimal places.
  public let latitude: Double

  /// The longitude in decimal degrees, rounded to four decimal places.
  public let longitude: Double

  /// Creates a coordinate after validating its range and rounding its values.
  ///
  /// - Parameters:
  ///   - latitude: A finite latitude from -90 through 90 degrees.
  ///   - longitude: A finite longitude from -180 through 180 degrees.
  /// - Throws: ``ValidationError`` when either value is invalid.
  public init(latitude: Double, longitude: Double) throws(ValidationError) {
    guard latitude.isFinite, (-90...90).contains(latitude) else { throw .invalidLatitude }
    guard longitude.isFinite, (-180...180).contains(longitude) else { throw .invalidLongitude }
    let roundedLatitude = (latitude * 10_000).rounded() / 10_000
    let roundedLongitude = (longitude * 10_000).rounded() / 10_000
    self.latitude = roundedLatitude == 0 ? 0 : roundedLatitude
    self.longitude = roundedLongitude == 0 ? 0 : roundedLongitude
  }
}
