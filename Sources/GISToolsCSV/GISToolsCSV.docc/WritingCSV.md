# Writing CSV

## Layouts

The writer has two layouts, controlled by
``CSVWriteOptions/geometryFormat``.

### Point layout

When the geometry format is ``CSVGeometryFormat/auto`` and every feature is a
simple `Point` in EPSG:4326, the output is:

```
id,longitude,latitude,altitude,<properties>
```

The altitude cell is empty when the coordinate has no altitude (or uses
``CSVWriteOptions/nullValue``). Points in other projections use the geometry
layout instead, so their coordinates are not misread as degrees.

### Geometry layout

When at least one feature is not an EPSG:4326 point, or when an explicit
geometry format is requested, the output is:

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
| ``CSVWriteOptions/geometryFormat`` | `.auto` | How geometry is written. |
| ``CSVWriteOptions/geometryColumnName`` | `"geometry"` | The geometry column name. It must not be empty or collide with a coordinate or id column. |
| ``CSVWriteOptions/includeHeader`` | `true` | Whether to write the header row. |
| ``CSVWriteOptions/nullValue`` | `""` | Text for missing properties and missing altitude. |
| ``CSVWriteOptions/lineEnding`` | `.lf` | `\n` or `\r\n`. |

## Geometry formats

| Format | Output |
|---|---|
| ``CSVGeometryFormat/auto`` | Point layout for EPSG:4326 points, WKT otherwise. |
| ``CSVGeometryFormat/wkt`` | WKT with an `SRID=4326;` prefix. |
| ``CSVGeometryFormat/ewkb`` | Uppercase hex-encoded EWKB. |
| ``CSVGeometryFormat/geojson`` | A compact GeoJSON geometry object. |

WKT, EWKB, and GeoJSON output is always reprojected to EPSG:4326, which is
the only projection GeoJSON can represent. Reading it back therefore also
yields EPSG:4326.

## Property columns

Property columns are ordered by first appearance across features, and
alphabetically within one feature. This is deterministic even though Swift
dictionaries do not have a stable iteration order. Property names are matched
case-insensitively; the first spelling encountered wins.

Properties whose names collide with reserved column names are omitted, because
the reader would misinterpret them. This includes `id` and the id aliases,
`geometry`/`geom`, latitude/longitude aliases, and altitude aliases (`z`,
`elev`, …).

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
