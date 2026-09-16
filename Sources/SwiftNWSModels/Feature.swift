#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A GeoJSON feature: one object the API describes, with its data in ``properties``.
///
/// Most responses in the API's default representation are a feature, so a response model is the
/// type of its properties wrapped in this one.
///
/// ```swift
/// let point: Feature<Point> = try JSONDecoder().decode(Feature<Point>.self, from: body)
/// print(point.properties.gridId)
/// ```
public struct Feature<Properties> {
  /// The URL that identifies the feature.
  public var id: URL?

  /// The data the feature describes.
  public var properties: Properties

  /// Creates a feature.
  ///
  /// - Parameters:
  ///   - id: The URL that identifies the feature.
  ///   - properties: The data the feature describes.
  public init(id: URL? = nil, properties: Properties) {
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
