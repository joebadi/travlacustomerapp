import 'dart:convert';

import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' show Theme, ThemeReader;

/// Self-hosted Nigeria vector tiles (OpenMapTiles schema) served from the VPS
/// PMTiles server behind Apache. Overridable at build time.
const _tileUrl = String.fromEnvironment(
  'TRAVLA_TILE_URL',
  defaultValue: 'https://travla.com.ng/tiles/nigeria/{z}/{x}/{y}.mvt',
);

Theme? _theme;

/// A flutter_map layer that renders Travla's self-hosted vector basemap.
/// Drop-in replacement for a raster `TileLayer`. Max data zoom is 14; the
/// renderer over-zooms beyond that.
VectorTileLayer travlaVectorTileLayer() {
  _theme ??= ThemeReader().read(
    jsonDecode(_styleJson) as Map<String, dynamic>,
  );
  return VectorTileLayer(
    theme: _theme!,
    maximumZoom: 20,
    tileProviders: TileProviders({
      'openmaptiles': NetworkVectorTileProvider(
        urlTemplate: _tileUrl,
        maximumZoom: 14,
        minimumZoom: 0,
      ),
    }),
  );
}

/// A compact MapLibre GL style over the OpenMapTiles schema — enough for a
/// clean, legible road map (no sprite/glyph servers needed; the renderer draws
/// labels with Flutter fonts).
const String _styleJson = '''
{
  "version": 8,
  "name": "Travla",
  "sources": {"openmaptiles": {"type": "vector"}},
  "layers": [
    {"id": "background", "type": "background", "paint": {"background-color": "#f4f2ee"}},
    {"id": "water", "type": "fill", "source": "openmaptiles", "source-layer": "water",
      "paint": {"fill-color": "#aad3df"}},
    {"id": "landcover-wood", "type": "fill", "source": "openmaptiles", "source-layer": "landcover",
      "filter": ["==", "class", "wood"], "paint": {"fill-color": "#d5e6cd", "fill-opacity": 0.7}},
    {"id": "landcover-grass", "type": "fill", "source": "openmaptiles", "source-layer": "landcover",
      "filter": ["==", "class", "grass"], "paint": {"fill-color": "#e0ead9", "fill-opacity": 0.7}},
    {"id": "landuse-residential", "type": "fill", "source": "openmaptiles", "source-layer": "landuse",
      "filter": ["==", "class", "residential"], "paint": {"fill-color": "#eceae4"}},
    {"id": "waterway", "type": "line", "source": "openmaptiles", "source-layer": "waterway",
      "paint": {"line-color": "#aad3df", "line-width": 1.2}},
    {"id": "road-minor", "type": "line", "source": "openmaptiles", "source-layer": "transportation",
      "filter": ["in", "class", "minor", "service", "track"],
      "paint": {"line-color": "#ffffff", "line-width": {"stops": [[12, 0.5], [16, 3]]}}},
    {"id": "road-secondary", "type": "line", "source": "openmaptiles", "source-layer": "transportation",
      "filter": ["in", "class", "secondary", "tertiary"],
      "paint": {"line-color": "#ffffff", "line-width": {"stops": [[9, 0.6], [16, 6]]}}},
    {"id": "road-primary", "type": "line", "source": "openmaptiles", "source-layer": "transportation",
      "filter": ["==", "class", "primary"],
      "paint": {"line-color": "#ffe4b3", "line-width": {"stops": [[8, 0.8], [16, 8]]}}},
    {"id": "road-trunk", "type": "line", "source": "openmaptiles", "source-layer": "transportation",
      "filter": ["in", "class", "trunk", "motorway"],
      "paint": {"line-color": "#f9b29c", "line-width": {"stops": [[6, 0.8], [16, 10]]}}},
    {"id": "building", "type": "fill", "source": "openmaptiles", "source-layer": "building",
      "minzoom": 14, "paint": {"fill-color": "#e2ded5", "fill-opacity": 0.7}},
    {"id": "boundary", "type": "line", "source": "openmaptiles", "source-layer": "boundary",
      "filter": ["<=", "admin_level", 4],
      "paint": {"line-color": "#9a9a9a", "line-width": 0.8, "line-dasharray": [3, 2]}},
    {"id": "place-label", "type": "symbol", "source": "openmaptiles", "source-layer": "place",
      "filter": ["in", "class", "city", "town", "village"],
      "layout": {"text-field": "{name}", "text-size": {"stops": [[6, 11], [12, 15]]}},
      "paint": {"text-color": "#3b3b3b", "text-halo-color": "#ffffff", "text-halo-width": 1.4}},
    {"id": "road-label", "type": "symbol", "source": "openmaptiles", "source-layer": "transportation_name",
      "minzoom": 13,
      "layout": {"text-field": "{name}", "text-size": 11},
      "paint": {"text-color": "#5a5a5a", "text-halo-color": "#ffffff", "text-halo-width": 1.2}}
  ]
}
''';
