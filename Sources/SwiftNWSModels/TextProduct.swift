#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One text product the service issues, as `/products/{productId}` describes it and the product
/// lists name it.
///
/// The identifier is always present. Every other field is optional because the routes differ in
/// what they send: a list entry carries no ``productText`` key at all, which is the shape of a
/// list rather than a bulletin with no words, so a nil text is never an empty bulletin and is
/// never filled in by fetching the product itself.
///
/// ``productText`` is the bulletin exactly as the service sends it, whatever whitespace, blank
/// lines, line endings, and heading lines it carries; the recorded area forecast discussion, for
/// example, opens with a newline ahead of its WMO heading. This package does not trim, normalize,
/// wrap, or interpret any of it. ``issuingOffice`` is the product's originating office in WMO
/// form, such as `KEWX`, which is a different vocabulary from the product location identifiers of
/// ``ProductLocations``, such as `EWX`; neither is derived from the other. Dates decode as ISO 8601
/// independently of the decoder's date strategy.
///
/// ```swift
/// let product = try await weather.latestProduct(at: "EWX", ofType: .areaForecastDiscussion)
/// print(product.productName ?? "")  // "Area Forecast Discussion"
/// ```
public struct TextProduct: Codable, Hashable, Sendable {
  /// The product's identifier, such as `a6addd61-6620-4718-9d53-effd7d8c2560`.
  public var id: String

  /// When the office issued the product.
  public var issuanceTime: Date?

  /// The WMO identifier of the office that issued the product, such as `KEWX`.
  ///
  /// This is not the product location identifier the product routes take, such as `EWX`. The two
  /// vocabularies are kept as the service sends them and neither is converted into the other.
  public var issuingOffice: String?

  /// The product's code, such as ``ProductCode/areaForecastDiscussion``.
  public var productCode: ProductCode?

  /// The product's name, such as `Area Forecast Discussion`.
  public var productName: String?

  /// The bulletin's text, exactly as the service sends it, or nil when the route omits it.
  ///
  /// Product lists send no text at all, so a nil value means the response was a list entry rather
  /// than an empty bulletin. The text keeps whatever whitespace, blank lines, line endings, and
  /// heading lines the service sent, such as the leading newline the recorded area forecast
  /// discussion arrived with.
  public var productText: String?

  /// The product's own API identity URL, from the response's `@id`.
  public var url: URL?

  /// The WMO collective identifier the product was transmitted under, such as `FXUS64`.
  public var wmoCollectiveId: String?

  /// Creates a text product.
  ///
  /// - Parameters:
  ///   - id: The product's identifier.
  ///   - issuanceTime: When the office issued the product.
  ///   - issuingOffice: The WMO identifier of the office that issued the product.
  ///   - productCode: The product's code.
  ///   - productName: The product's name.
  ///   - productText: The bulletin's text, exactly as the service sends it.
  ///   - url: The product's own API identity URL.
  ///   - wmoCollectiveId: The WMO collective identifier the product was transmitted under.
  public init(
    id: String,
    issuanceTime: Date? = nil,
    issuingOffice: String? = nil,
    productCode: ProductCode? = nil,
    productName: String? = nil,
    productText: String? = nil,
    url: URL? = nil,
    wmoCollectiveId: String? = nil
  ) {
    self.id = id
    self.issuanceTime = issuanceTime
    self.issuingOffice = issuingOffice
    self.productCode = productCode
    self.productName = productName
    self.productText = productText
    self.url = url
    self.wmoCollectiveId = wmoCollectiveId
  }

  /// Decodes a text product, reading its issuance time as ISO 8601 text.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError` for a missing identifier, an issuance time that is not ISO 8601, or
  ///   an identity link that is not a URL.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      id: try container.decode(String.self, forKey: .id),
      issuanceTime: try container.decodeISO8601IfPresent(forKey: .issuanceTime),
      issuingOffice: try container.decodeIfPresent(String.self, forKey: .issuingOffice),
      productCode: try container.decodeIfPresent(ProductCode.self, forKey: .productCode),
      productName: try container.decodeIfPresent(String.self, forKey: .productName),
      productText: try container.decodeIfPresent(String.self, forKey: .productText),
      url: try container.decodeIfPresent(URL.self, forKey: .url),
      wmoCollectiveId: try container.decodeIfPresent(String.self, forKey: .wmoCollectiveId)
    )
  }

  /// Encodes the product, writing its issuance time as ISO 8601 text.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encodeIfPresent(
      issuanceTime?.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)),
      forKey: .issuanceTime)
    try container.encodeIfPresent(issuingOffice, forKey: .issuingOffice)
    try container.encodeIfPresent(productCode, forKey: .productCode)
    try container.encodeIfPresent(productName, forKey: .productName)
    try container.encodeIfPresent(productText, forKey: .productText)
    try container.encodeIfPresent(url, forKey: .url)
    try container.encodeIfPresent(wmoCollectiveId, forKey: .wmoCollectiveId)
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case issuanceTime
    case issuingOffice
    case productCode
    case productName
    case productText
    case url = "@id"
    case wmoCollectiveId
  }
}
