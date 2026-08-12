import Foundation

// MARK: - Column roles

/// The role a CSV column plays in building a ``Feature``.
enum CSVColumnRole: Equatable {
    /// A `geometry`/`geom` column containing WKT.
    case geometry
    /// A latitude column.
    case latitude
    /// A longitude column.
    case longitude
    /// An altitude column mapped onto a point's coordinate altitude.
    case altitude
    /// A column used for the Feature id.
    case id
    /// A plain property column.
    case property
}

// MARK: - Column mapping

/// Maps a CSV header to the roles of its columns.
///
/// Column names are matched case-insensitively, so `FEATURE_IDENTIFIER` and
/// `feature_identifier` are treated the same.
struct CSVColumnMapping {

    /// The detected role for each header column (aligned with `headers`).
    let roles: [CSVColumnRole]

    /// The header column names (in original form).
    let headers: [String]

    /// The 0-based index of the geometry column, if any.
    let geometryIndex: Int?

    /// The 0-based index of the latitude column, if any.
    let latitudeIndex: Int?

    /// The 0-based index of the longitude column, if any.
    let longitudeIndex: Int?

    /// The 0-based index of the altitude column, if any.
    let altitudeIndex: Int?

    /// The 0-based index of the id column, if any.
    let idIndex: Int?

    /// Whether any geometry-bearing column (geometry or a lat/lon pair) exists.
    var hasGeometrySource: Bool {
        geometryIndex != nil || (latitudeIndex != nil && longitudeIndex != nil)
    }

    /// The set of normalized header names accepted as an id column.
    ///
    /// The canonical column `id` wins; a range of common variants
    /// (`feature_id`, `feature_identifier`, `identifier`, `fid`, …) are
    /// also accepted. All are matched case-insensitively.
    private static let idAliases: Set<String> = [
        "id",
        "feature_id", "featureid",
        "feature_identifier", "featureidentifier",
        "identifier", "ident",
        "fid", "objectid", "object_id", "gid", "idfield",
    ]

    /// Builds a mapping from a header row.
    ///
    /// - Parameter headers: The header column names, in order.
    init(headers: [String]) {
        var roles: [CSVColumnRole] = []
        var geometryIndex: Int? = nil
        var latitudeIndex: Int? = nil
        var longitudeIndex: Int? = nil
        var altitudeIndex: Int? = nil
        var idIndex: Int? = nil

        for (index, header) in headers.enumerated() {
            let normalized = header.trimmingCharacters(in: .whitespaces).lowercased()
            switch normalized {
            case "geometry", "geom":
                roles.append(.geometry)
                geometryIndex = index
            case "latitude", "lat":
                roles.append(.latitude)
                latitudeIndex = index
            case "longitude", "long", "lng":
                roles.append(.longitude)
                longitudeIndex = index
            case "altitude", "elevation", "elev", "z":
                roles.append(.altitude)
                altitudeIndex = index
            default:
                if Self.idAliases.contains(normalized) {
                    roles.append(.id)
                    idIndex = index
                }
                else {
                    roles.append(.property)
                }
            }
        }

        self.roles = roles
        self.headers = headers
        self.geometryIndex = geometryIndex
        self.latitudeIndex = latitudeIndex
        self.longitudeIndex = longitudeIndex
        self.altitudeIndex = altitudeIndex
        self.idIndex = idIndex
    }

}
