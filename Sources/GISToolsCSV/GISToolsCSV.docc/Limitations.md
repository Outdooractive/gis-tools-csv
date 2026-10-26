# Limitations

CSV is a flat text format without a schema, so some GeoJSON concepts cannot
survive a round-trip.

## Header required

Geometry is never guessed from column order. A header row must exist and must
contain either a `geometry`/`geom` column or a latitude/longitude pair.
Otherwise reading fails with ``CSVError/missingGeometryColumns``.

## No projection information

CSV has no place for a CRS. Latitude/longitude columns are always interpreted
as EPSG:4326 degrees. Geometry columns may carry an SRID in WKT or EWKB, and
the reader reprojects them to EPSG:4326. There is no read option to request a
different target projection.

## Metadata is lost

CSV has no equivalent of GeoJSON foreign members, collection metadata, or
bounding boxes. Feature and collection foreign members are not written.

## Property names are restricted

The reader recognizes role columns by name. A property named `id`, `geometry`,
`lat`, `lon`, `z`, or any other reserved alias cannot be represented, because
writing it would create a column the reader treats as a role. The writer
omits such properties. Rename them before writing if the data matters.

Property names are matched case-insensitively on write; the first spelling
wins. Two properties that differ only in case are therefore collapsed. If a
header contains more than one column for the same role (for example two
`geometry` columns), the last column wins.

## Types are inferred

CSV values have no type. The reader infers `Bool`, `Int`, `Double`, or `String`
from the text. A string property that looks like a canonical number (`1`) or
boolean (`true`) reads back as that type. Leading-zero strings such as `00123`
stay strings, but a string `"1"` cannot be distinguished from an integer.

Nested values (arrays, dictionaries, dates, and other non-scalar types) are
written using their Swift textual description and are not reconstructed as the
original type. `NULL` and empty values can be omitted on read with
``CSVNullHandling/omit``.

## Unlocated features

An empty or `NULL` geometry cell becomes an unlocated feature when no
latitude/longitude pair is available. The writer can emit unlocated features, and the reader can
restore them, but a collection containing only unlocated features cannot use
the point layout.

## Encoding and memory

Input must be UTF-8. Other encodings fail with
``CSVError/invalidEncoding``. The whole file is decoded into memory before
parsing, so very large files are not streamed.

## Malformed input

The parser is lenient about quotes inside unquoted fields and characters after
a closing quote. It rejects an unterminated quoted field with
``CSVError/malformedCSV(detail:)``. It does not attempt to repair quotes that
start in the middle of a field.
