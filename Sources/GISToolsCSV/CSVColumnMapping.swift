import Foundation

// MARK: - Column roles

/// The role a CSV column plays in building a `Feature`.
enum CSVColumnRole: Equatable {

    /// A `geometry`/`geom` column containing a serialized geometry.
    case geometry
    /// A latitude column.
    case latitude
    /// A longitude column.
    case longitude
    /// An altitude column mapped onto a point's coordinate altitude.
    case altitude
    /// A column used for the Feature id.
    case id
    /// A column containing a CRS/projection identifier.
    case projection
    /// A plain property column.
    case property

}

// MARK: - Column mapping

/// Maps a CSV header to the roles of its columns.
///
/// Column names are matched case-insensitively, so `FEATURE_IDENTIFIER` and
/// `feature_identifier` are treated the same.
struct CSVColumnMapping {

    /// The header names accepted as a geometry column.
    static let geometryAliases: Set<String> = ["geometry", "geom"]

    /// The header names accepted as a latitude column.
    static let latitudeAliases: Set<String> = ["latitude", "lat"]

    /// The header names accepted as a longitude column.
    static let longitudeAliases: Set<String> = ["longitude", "long", "lon", "lng"]

    /// The header names accepted as x/y coordinate aliases when no
    /// longitude/latitude columns are present.
    static let xAliases: Set<String> = ["x"]
    static let yAliases: Set<String> = ["y"]

    /// The header names accepted as an altitude column.
    static let altitudeAliases: Set<String> = ["altitude", "elevation", "elev", "z"]

    /// Header names accepted as a CRS/projection column.
    static let projectionAliases: Set<String> = ["projection", "crs", "srid"]

    /// The set of normalized header names accepted as an id column.
    ///
    /// The canonical column `id` wins; a range of common variants
    /// (`feature_id`, `feature_identifier`, `identifier`, `fid`, …) are
    /// also accepted. All are matched case-insensitively.
    static let idAliases: Set<String> = [
        "id",
        "feature_id",
        "featureid",
        "feature_identifier",
        "featureidentifier",
        "identifier",
        "ident",
        "fid",
        "objectid",
        "object_id",
        "gid",
        "idfield",
    ]

    /// Every header name that is interpreted as a role instead of a property.
    ///
    /// The writer uses this set to avoid creating property columns that the
    /// reader would misinterpret.
    static let allReservedNames: Set<String> = geometryAliases
        .union(latitudeAliases)
        .union(longitudeAliases)
        .union(altitudeAliases)
        .union(xAliases)
        .union(yAliases)
        .union(idAliases)

    /// Header names that must not be used for the geometry column itself.
    ///
    /// A custom geometry column may be named `geometry`/`geom`, but naming it
    /// after a coordinate or id column would make the output unreadable.
    static let nonGeometryReservedNames: Set<String> = latitudeAliases
        .union(longitudeAliases)
        .union(altitudeAliases)
        .union(xAliases)
        .union(yAliases)
        .union(idAliases)

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

    /// The 0-based index of the CRS/projection column, if any.
    let projectionIndex: Int?

    /// Whether any geometry-bearing column (geometry or a lat/lon pair) exists.
    var hasGeometrySource: Bool {
        geometryIndex != nil || (latitudeIndex != nil && longitudeIndex != nil)
    }

    /// Builds a mapping from a header row.
    ///
    /// - Parameter headers: The header column names, in order.
    init(headers: [String]) {
        let normalizedHeaders = headers.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        var geometryIndex: Int? = nil
        var altitudeIndex: Int? = nil
        var idIndex: Int? = nil
        var projectionIndex: Int? = nil

        // Prefer the canonical longitude/latitude names. Fall back to x/y
        // only when neither canonical coordinate column is present, so a
        // CSV containing both `longitude` and an `x` property remains
        // unambiguous.
        var latitudeIndex = normalizedHeaders.firstIndex {
            Self.latitudeAliases.contains($0)
        }
        var longitudeIndex = normalizedHeaders.firstIndex {
            Self.longitudeAliases.contains($0)
        }
        if latitudeIndex == nil, longitudeIndex == nil {
            latitudeIndex = normalizedHeaders.firstIndex {
                Self.yAliases.contains($0)
            }
            longitudeIndex = normalizedHeaders.firstIndex {
                Self.xAliases.contains($0)
            }
        }

        var roles: [CSVColumnRole] = []
        for (index, normalized) in normalizedHeaders.enumerated() {
            if Self.geometryAliases.contains(normalized) {
                roles.append(.geometry)
                geometryIndex = index
            }
            else if index == latitudeIndex {
                roles.append(.latitude)
            }
            else if index == longitudeIndex {
                roles.append(.longitude)
            }
            else if Self.altitudeAliases.contains(normalized) {
                roles.append(.altitude)
                altitudeIndex = index
            }
            else if Self.projectionAliases.contains(normalized) {
                roles.append(.projection)
                projectionIndex = index
            }
            else if Self.idAliases.contains(normalized) {
                roles.append(.id)
                idIndex = index
            }
            else {
                roles.append(.property)
            }
        }

        self.roles = roles
        self.headers = headers
        self.geometryIndex = geometryIndex
        self.latitudeIndex = latitudeIndex
        self.longitudeIndex = longitudeIndex
        self.altitudeIndex = altitudeIndex
        self.idIndex = idIndex
        self.projectionIndex = projectionIndex
    }

}
