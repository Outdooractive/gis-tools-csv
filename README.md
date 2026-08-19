# GISToolsCSV

CSV read and write support for Swift, built on top of [**gis-tools**](https://github.com/Outdooractive/gis-tools). Parses CSV rows into typed `FeatureCollection` objects — and writes them back as CSV.

## Features

- Reads and writes CSV files, with a configurable delimiter (`,` `;` `\t` or any character)
- Works directly with Postgres/Postgis CSV exports (`COPY TO`)
- **Header required** — geometry is never guessed
- Geometry columns (`geometry`, `geom`) parsed with **format auto-detection**: WKT (with or without an `SRID=…;` prefix), hex-encoded WKB/EWKB/TWKB, or GeoJSON
- Point geometry from `latitude`/`longitude` (and aliases), with optional `altitude`
- Feature ids from an `id` column (and many aliases), matched case-insensitively
- All other columns become `Feature` properties (booleans, ints, doubles, strings)
- RFC 4180-style quoting: embedded delimiters, quotes, and newlines
- Writing always emits a header; uses `geometry` (WKT) for complex features and `longitude`/`latitude`/`altitude` for simple points

## Requirements

Swift 6.1 or higher. Compiles on iOS (≥ iOS 15), macOS (≥ macOS 15), tvOS (≥ tvOS 15), watchOS (≥ watchOS 7), Linux, Android and Wasm. No external dependencies beyond the base `gis-tools` package.

## Installation with Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/Outdooractive/gis-tools-csv", from: "1.0.0"),
    .package(url: "https://github.com/Outdooractive/gis-tools", from: "2.0.0"),
],
targets: [
    .target(name: "MyTarget", dependencies: [
        .product(name: "GISToolsCSV", package: "gis-tools-csv"),
        .product(name: "GISTools", package: "gis-tools"),
    ]),
]
```

## Usage

### Reading

```swift
import GISTools
import GISToolsCSV

let url = URL(fileURLWithPath: "/path/to/file.csv")
let fc = try CSVCoder.read(from: url)

// With a non-default delimiter:
let fc = try CSVCoder.read(from: url, options: CSVReadOptions(delimiter: ";"))

// Omit NULL and empty values from properties (e.g. PostGIS exports):
let fc = try CSVCoder.read(from: url, options: CSVReadOptions(nullHandling: .omit))

// Or via the convenience init:
guard let fc = FeatureCollection(csv: url) else { return }
```

`CSVReadOptions` controls how a CSV is read:

| Option | Default | Description |
|---|---|---|
| `delimiter` | `","` | The field delimiter. |
| `nullHandling` | `.keepAsString` | How `NULL` and empty values are treated. `.keepAsString` keeps them as strings; `.omit` drops the property entirely. `NULL` is matched case-insensitively. |

### Writing

```swift
try fc.writeCSV(to: outputURL)

// Or via the coder directly:
try CSVCoder.write(fc, to: outputURL)

// Serialize to Data:
let data = try CSVCoder.write(fc)

// Write geometry as EWKB hex:
try CSVCoder.write(fc, to: outputURL, options: CSVWriteOptions(geometryFormat: .ewkb))
```

`CSVWriteOptions` controls how a `FeatureCollection` is written:

| Option | Default | Description |
|---|---|---|
| `delimiter` | `","` | The field delimiter. |
| `geometryFormat` | `.auto` | How geometry is written. `.auto` uses `longitude`/`latitude`/`altitude` columns for all-points collections and a WKT geometry column otherwise. `.wkt`, `.ewkb` (hex), and `.geojson` always emit a geometry column. |
| `geometryColumnName` | `"geometry"` | The name of the geometry column. |
| `includeHeader` | `true` | Whether to write the header row. |
| `nullValue` | `""` | The value written for `nil` properties (e.g. `"NULL"`). |
| `lineEnding` | `.lf` | The line ending between rows (`.lf` or `.crlf`). |

### Column mapping (reading)

The header row is matched **case-insensitively**:

| Role            | Accepted column names                          |
|-----------------|------------------------------------------------|
| Geometry        | `geometry`, `geom`                             |
| Latitude        | `latitude`, `lat`                              |
| Longitude       | `longitude`, `long`, `lng`                     |
| Altitude        | `altitude`, `elevation`, `elev`, `z`           |
| Feature id      | `id`, `feature_id`, `feature_identifier`, `identifier`, `fid`, `objectid`, … |

Any other column becomes a ``Feature`` property. Numeric properties are parsed as `Int` or `Double`, `true`/`false` as `Bool`, everything else stays a `String`.

If a row has a `geometry` column it is used as-is. The format is auto-detected, so it may be WKT (e.g. `POINT (11.5 48.1)` or `SRID=4326;LINESTRING (…)`), a hex-encoded PostGIS EWKB/WKB/TWKB string, or GeoJSON — and it may decode to a `Point`, `LineString`, `Polygon`, … Otherwise, if a latitude and longitude column are both present, a `Point` is built. A row with neither is an error.

### Column mapping (writing)

The header is always written. If **every** feature is a simple `Point`, the output uses `id`, `longitude`, `latitude`, `altitude`, then the remaining property columns. Otherwise the geometry column is written **last** (it can be long) as WKT, named `geometry`:

```
// all points:
id,longitude,latitude,altitude,name
1,11.518585,48.135125,520,Marienplatz

// mixed/complex:
id,name,geometry
2,Trail,"SRID=4326;LINESTRING(10.22 47.56,10.3 47.62)"
```

Feature ids are always written to the `id` column (empty if a feature has none).

## API Reference

| API | Description |
|---|---|
| `CSVCoder.read(from url:options:)` | Reads a CSV file into a `FeatureCollection` |
| `CSVCoder.read(from data:options:)` | Reads CSV data into a `FeatureCollection` |
| `CSVCoder.write(_:options:)` | Serializes a `FeatureCollection` to CSV `Data` |
| `CSVCoder.write(_:to:options:)` | Writes a `FeatureCollection` to a CSV file |
| `CSVReadOptions` | Options controlling CSV reading (`delimiter`, `nullHandling`) |
| `CSVWriteOptions` | Options controlling CSV writing (`delimiter`, `geometryFormat`, `geometryColumnName`, `includeHeader`, `nullValue`, `lineEnding`) |
| `FeatureCollection(csv:options:)` | Convenience init from a CSV file |
| `FeatureCollection(csvData:options:)` | Convenience init from CSV data |
| `FeatureCollection.csvData(options:)` | Serializes the receiver to CSV `Data` |
| `FeatureCollection.writeCSV(to:options:)` | Writes the receiver as a CSV file |

## Limitations

- A header row is required — geometry columns are never guessed.
- Written geometry uses the configured `geometryColumnName` (default `geometry`) and is emitted as WKT by default.
- Property columns on write are ordered by first appearance across all features.

## Contributing

Please [create an issue](https://github.com/Outdooractive/gis-tools-csv/issues) or [open a pull request](https://github.com/Outdooractive/gis-tools-csv/pulls) with a fix or enhancement.

## License

MIT

## Authors

Thomas Rasch, Outdooractive

Built on top of [**gis-tools**](https://github.com/Outdooractive/gis-tools).
