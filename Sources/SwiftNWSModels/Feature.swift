#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A GeoJSON feature: one object the API describes, with its data in ``properties``.
///
/// Most responses in the API's default representation are a feature, so a response model is the
/// type of its properties wrapped in this one. The feature's geometry is retained as raw JSON when
/// the service sends one; the package does not validate or interpret it.
///
/// ```swift
/// let point: Feature<Point> = try JSONDecoder().decode(Feature<Point>.self, from: body)
/// print(point.properties.gridId)
/// ```
public struct Feature<Properties> {
  /// The feature's GeoJSON geometry as raw JSON, or nil when the service sends `null` or none.
  ///
  /// Zone details carry a polygon; directory listings and most other responses carry `null`. The
  /// value is the geometry object exactly as sent, with no validation, coordinate types, or spatial
  /// computation.
  public var geometry: JSONValue?

  /// The URL that identifies the feature.
  public var id: URL?

  /// The data the feature describes.
  public var properties: Properties

  /// Creates a feature.
  ///
  /// - Parameters:
  ///   - geometry: The feature's GeoJSON geometry as raw JSON.
  ///   - id: The URL that identifies the feature.
  ///   - properties: The data the feature describes.
  public init(geometry: JSONValue? = nil, id: URL? = nil, properties: Properties) {
    self.geometry = geometry
    self.id = id
    self.properties = properties
  }
}

extension Feature: Decodable where Properties: Decodable {}
extension Feature: Encodable where Properties: Encodable {}
extension Feature: Equatable where Properties: Equatable {}
extension Feature: Hashable where Properties: Hashable {}
extension Feature: Sendable where Properties: Sendable {}

/// A GeoJSON feature collection: a list of objects the API describes.
///
/// ```swift
/// let stations = try JSONDecoder().decode(FeatureCollection<ObservationStation>.self, from: body)
/// let nearest = stations.features.first?.properties
/// ```
public struct FeatureCollection<Properties> {
  /// The features in the collection, in the order the API listed them.
  public var features: [Feature<Properties>]

  /// The unvalidated continuation metadata, or nil when the collection is terminal.
  public var pagination: PaginationInfo?

  /// Creates a feature collection.
  ///
  /// - Parameters:
  ///   - features: The features in the collection.
  ///   - pagination: The unvalidated continuation metadata, or nil for a terminal collection.
  public init(features: [Feature<Properties>], pagination: PaginationInfo? = nil) {
    self.features = features
    self.pagination = pagination
  }
}

extension FeatureCollection: Decodable where Properties: Decodable {}
extension FeatureCollection: Encodable where Properties: Encodable {}
extension FeatureCollection: Equatable where Properties: Equatable {}
extension FeatureCollection: Hashable where Properties: Hashable {}
extension FeatureCollection: Sendable where Properties: Sendable {}
