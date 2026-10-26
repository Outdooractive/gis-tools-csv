# Reading CSV

## Header mapping

A header row is required. Column names are matched case-insensitively and may
have surrounding whitespace. The following roles are recognized:

| Role | Accepted column names |
|---|---|
| Geometry | `geometry`, `geom` |
| Latitude / Y | `latitude`, `lat`, `y` |
| Longitude / X | `longitude`, `long`, `lon`, `lng`, `x` |
| Altitude / Z | `altitude`, `elevation`, `elev`, `z` |
| CRS / projection | `projection`, `crs`, `srid` |
| Feature id | `id`, `feature_id`, `feature_identifier`, `identifier`, `ident`, `fid`, `objectid`, `object_id`, `gid`, `idfield` |

Every other column becomes a `Feature` property. `x`/`y` are used as
coordinate aliases only when neither a longitude nor a latitude alias is
present; this keeps a file containing both `longitude` and an `x` property
unambiguous. If the header contains no geometry column and no coordinate pair,
reading fails with ``CSVError/missingGeometryColumns``.

## Geometry detection

A non-empty geometry cell is auto-detected as one of:

- WKT, with or without an `SRID=…;` prefix, for example
  `POINT (11.5 48.1)` or `SRID=4326;LINESTRING (…)`
- Hex-encoded WKB, EWKB, or TWKB, such as the output of PostGIS
- A GeoJSON geometry object

WKT/WKB values without an embedded SRID are interpreted in
``CSVReadOptions/projection``. Embedded SRIDs are honored, and GeoJSON geometry
cells remain EPSG:4326. The returned geometry uses the selected projection.

If the geometry cell is empty or `NULL`, a latitude/longitude pair is used when
available. If there is no pair either, the row becomes an unlocated feature
(no geometry), which matches a `NULL` geometry in a PostGIS export.

If both a geometry column and coordinate columns exist, the geometry column
wins whenever it is non-empty.

For EPSG:4326, coordinate values must be finite and within -90…90 and
-180…180 degrees. Other projections use the projection's valid extent. The
altitude is optional; an empty or `NULL` altitude becomes `nil`.

A `projection`, `crs`, or `srid` column overrides
``CSVReadOptions/projection`` for the whole file. Non-empty values must all
resolve to the same projection; empty cells use the option fallback. Values may
be plain SRIDs, `EPSG:n`, `urn:ogc:def:crs:EPSG::n`, `SRID=n`, `noSRID`/`none`,
or recognized WKT.

## Options

``CSVReadOptions`` controls parsing:

| Option | Default | Description |
|---|---|---|
| ``CSVReadOptions/delimiter`` | `","` | The field delimiter. Any single `Character` is accepted, including multi-scalar graphemes. |
| ``CSVReadOptions/nullHandling`` | `.keepAsString` | How `NULL` and empty property values are handled. |
| ``CSVReadOptions/projection`` | `.epsg4326` | CRS of the coordinate values and unlabelled geometry cells. |
| ``CSVReadOptions/treatAsLineString`` | `false` | Concatenate all coordinates into one `LineString`. |

### Null handling

With ``CSVNullHandling/keepAsString`` the text `NULL` (case-insensitive) and
empty values stay in the properties dictionary as strings. With
``CSVNullHandling/omit`` those properties are omitted entirely. Null handling
also applies to the id column and to an optional altitude; latitude and
longitude are always required.

### Treat as line string

``CSVReadOptions/treatAsLineString`` concatenates all row coordinates in file
order into a single `LineString` feature. It works with latitude/longitude
rows and with `POINT`, `MULTIPOINT`, `LINESTRING`, and `MULTILINESTRING`
geometry cells. Other geometry types are rejected, and at least two
coordinates are required. Row properties and ids are dropped.

## Encoding, line endings, and quoting

- Input must be UTF-8. A leading UTF-8 byte order mark is ignored.
- `\n`, `\r\n`, and lone `\r` line endings are supported.
- RFC 4180-style quoting is supported: embedded delimiters, quotes (`""`),
  and newlines.
- A quote inside an unquoted field is treated as data, not dropped.
- An unterminated quoted field throws ``CSVError/malformedCSV(detail:)``
  instead of silently swallowing the rest of the file.
- A completely blank line is ignored. A line containing delimiters is a
  record, even if all of its fields are empty.

## Numeric inference

Property values are inferred as `Bool`, `Int`, `Double`, or `String`:

- `true` and `false` are case-insensitive booleans.
- Only canonical integer spellings become `Int`. `00123` and `+1` stay
  strings so postal codes and ids keep their leading zeros or signs.
- Values containing a decimal point or an exponent become `Double` when
  finite. `NaN` and `Infinity` stay strings because they cannot be
  represented in JSON.

## Convenience API

```swift
let fromData = FeatureCollection(csvData: data)
let fromFile = FeatureCollection(csv: csvURL)
```

Both return `nil` on failure. Use ``CSVCoder`` when you need the underlying
``CSVError``.
