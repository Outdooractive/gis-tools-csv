# Changelog

All notable changes to this project are documented in this file.

## Unreleased

## 3.0.0 - 2026-10-30

### Breaking changes

- Updated to `gis-tools` 3.0.0. `Feature.geometry` is optional in
  that release, and unlocated features are now supported throughout the
  reader and writer.
- A header without a geometry column and without a latitude/longitude pair now
  throws `CSVError.missingGeometryColumns` instead of `CSVError.missingHeader`.
- An unterminated quoted field now throws `CSVError.malformedCSV` instead of
  silently swallowing the rest of the file.
- Latitude and longitude values are validated as finite EPSG:4326 coordinates
  (-90…90 and -180…180). An invalid altitude now throws instead of being
  silently ignored.
- Writing omits properties whose names collide with reserved column names
  (`id`, `geometry`, `geom`, `lat`, `lon`, `lng`, `z`, `fid`, …) instead of
  producing duplicate columns that the reader misinterprets.
- Numeric inference only converts canonical integers. Leading-zero values such
  as `00123` and values such as `+1` stay strings. `NaN` and `Infinity` stay
  strings.
- `Double` properties and ids are written with a `.0` suffix for whole numbers
  and with the shortest round-trip representation, so they read back as
  `Double` instead of `Int`.
- `.auto` now uses the point layout for all-point collections in any
  projection. EPSG:4326 keeps longitude/latitude/altitude names; other
  projections use x/y/z by default.
- CSV output uses the collection's projection by default. Existing projected
  collections that relied on implicit reprojection to EPSG:4326 must set
  `CSVWriteOptions(projection: .epsg4326)`.
- `.geojson` output still reprojects geometry to EPSG:4326.
- The `CSVError` descriptions for parsed geometry errors no longer contain a
  duplicated `Invalid geometry:` prefix.

### Added

- `lon` as a longitude column alias.
- `CSVReadOptions.projection` and `CSVWriteOptions.projection` for arbitrary
  registered projections.
- `x`/`y` coordinate column aliases and `CSVCoordinateColumns` for selecting
  longitude/latitude or x/y point layouts.
- `projection`/`crs`/`srid` CSV columns with consistent file-level CRS
  handling, plus `CSVWriteOptions.projectionColumnName` for writing a CRS
  column.
- `CSVError.malformedCSV(detail:)`, `CSVError.missingGeometryColumns`, and
  `CSVError.invalidGeometryColumnName(name:)`.
- `Equatable` and `Hashable` conformances for `CSVReadOptions`,
  `CSVWriteOptions`, `CSVNullHandling`, `CSVGeometryFormat`, and
  `CSVLineEnding`.
- Reading an empty geometry cell as an unlocated feature when no coordinate
  pair is available. Writing an unlocated feature as an empty geometry cell.
- DocC catalog with getting started, reading, writing, and limitations
  articles.
- `scripts/build-documentation.sh` and `scripts/coverage.sh`.
- Linux CI with coverage and documentation checks; macOS CI retains the test
  run.

### Fixed
- CRLF characters inside quoted fields are now quoted correctly during writing
  on all platforms (CRLF is a single grapheme cluster in Swift strings).

- UTF-8 byte order marks no longer break header detection.
- A quote inside an unquoted field is preserved instead of dropped.
- Duplicate `id` columns when a feature has a property named `id`.
- Nondeterministic property column order caused by dictionary iteration.
- `FeatureCollection.writeCSV(to:)` now wraps file system errors in
  `CSVError.fileWriteError`, matching `CSVCoder.write(_:to:options:)`.
- Writing an empty collection with `includeHeader: false` now produces empty
  data instead of a single newline.
- Double precision loss from the previous `%.9g` formatting.
- Id overflow on 32-bit platforms and non-finite `Double` ids.
- Semicolon delimiter test data with a trailing newline.
- The `.spi.yml` documentation target now points at `GISToolsCSV`.
