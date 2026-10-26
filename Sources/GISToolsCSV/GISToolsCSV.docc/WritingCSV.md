# Writing CSV

## Layouts

The writer has two layouts, controlled by
``CSVWriteOptions/geometryFormat``.

### Point layout

When the geometry format is ``CSVGeometryFormat/auto`` and every feature is a
simple `Point`, the output uses a point layout. EPSG:4326 defaults to:

```
id,longitude,latitude,altitude,<properties>
```

Other projections default to:

```
id,x,y,z,<properties>
```

``CSVWriteOptions/coordinateColumns`` can force `.longitudeLatitude` or `.xy`
for either case. The altitude cell is empty when the coordinate has no altitude
(or uses ``CSVWriteOptions/nullValue``).

### Geometry layout

When at least one feature is not a point, or when an explicit geometry format
is requested, the output is:

```
id,<properties>,geometry
```

The geometry column is last because its values can be long. An unlocated
feature is written as an empty geometry cell and reads back as an unlocated
feature.

## Options

``CSVWriteOptions`` controls output:

| Option | Default | Description |
|---|---|---|
| ``CSVWriteOptions/delimiter`` | `","` | The field delimiter. |
| ``CSVWriteOptions/projection`` | `nil` | Output projection. `nil` preserves the collection projection. |
| ``CSVWriteOptions/coordinateColumns`` | `.automatic` | Point-layout names: longitude/latitude/altitude for 4326, x/y/z otherwise. |
| ``CSVWriteOptions/projectionColumnName`` | `nil` | Optional `projection`/`crs`/`srid` column with the output CRS in every row. |
| ``CSVWriteOptions/geometryFormat`` | `.auto` | How geometry is written. |
| ``CSVWriteOptions/geometryColumnName`` | `"geometry"` | The geometry column name. It must not be empty or collide with a coordinate or id column. |
| ``CSVWriteOptions/includeHeader`` | `true` | Whether to write the header row. |
| ``CSVWriteOptions/nullValue`` | `""` | Text for missing properties and missing altitude. |
| ``CSVWriteOptions/lineEnding`` | `.lf` | `\n` or `\r\n`. |

## Geometry formats

| Format | Output |
|---|---|
| ``CSVGeometryFormat/auto`` | Point layout for all-point collections, WKT otherwise. |
| ``CSVGeometryFormat/wkt`` | WKT in the output projection, with an SRID prefix. |
| ``CSVGeometryFormat/ewkb`` | Uppercase hex-encoded EWKB in the output projection. |
| ``CSVGeometryFormat/geojson`` | A compact GeoJSON geometry object in EPSG:4326. |

WKT and EWKB output uses the output projection (the collection projection
unless ``CSVWriteOptions/projection`` is set). GeoJSON output is always
EPSG:4326, as required by the GeoJSON specification. Use
``CSVWriteOptions/projectionColumnName`` to emit a CRS column explicitly; the
value is `EPSG:<srid>` or `noSRID`.

## Property columns

Property columns are ordered by first appearance across features, and
alphabetically within one feature. This is deterministic even though Swift
dictionaries do not have a stable iteration order. Property names are matched
case-insensitively; the first spelling encountered wins.

Properties whose names collide with reserved column names are omitted, because
the reader would misinterpret them. This includes `id` and the id aliases,
`geometry`/`geom`, latitude/longitude aliases, and altitude aliases (`z`,
`elev`, …). When the point layout uses `x`/`y` columns, properties named `x`
and `y` are also omitted.

Whole-number `Double` properties keep a `.0` suffix so they read back as
`Double` instead of `Int`. Values use Swift's shortest round-trip
representation. Strings are written verbatim and quoted only when they contain
the delimiter, a quote, or a line ending.

## Feature ids

Feature ids are written to the `id` column and are empty when a feature has no
id. Numeric ids keep their numeric type. String ids that look exactly like a
canonical integer (`1`), unsigned integer, or double (`1.0`) are read back as
numbers; use a non-numeric spelling when the id must stay a string.

## Convenience API

```swift
let data = try collection.csvData()
try collection.writeCSV(to: outputURL)
```

`FeatureCollection.writeCSV(to:options:)` wraps file system errors in
``CSVError/fileWriteError(detail:)``, like ``CSVCoder`` does.
