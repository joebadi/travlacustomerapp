import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

/// Base of the self-hosted vector tile server (see journey_vector_map).
const _tileBase = String.fromEnvironment(
  'TRAVLA_TILE_BASE',
  defaultValue: 'https://travla.com.ng/tiles/nigeria',
);

/// Zoom range packed for offline. Our data maxes at z14; the renderer
/// over-zooms beyond that.
const int _minPackZoom = 10;
const int _maxPackZoom = 14;

String _tileUrl(int z, int x, int y) => '$_tileBase/$z/$x/$y.mvt';

int _xTile(double lon, int z) => ((lon + 180.0) / 360.0 * (1 << z)).floor();
int _yTile(double lat, int z) {
  final r = lat * math.pi / 180.0;
  return ((1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2 * (1 << z))
      .floor();
}

/// Per-journey local store of downloaded vector tiles, so a saved route can be
/// followed with no signal.
class OfflineTileStore {
  static Future<Directory> dirFor(String journeyId) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/journey_tiles/$journeyId');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static File tileFile(Directory dir, int z, int x, int y) =>
      File('${dir.path}/${z}_${x}_$y.mvt');

  static Future<bool> hasPack(String journeyId) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/journey_tiles/$journeyId');
    if (!await dir.exists()) return false;
    return dir.listSync().isNotEmpty;
  }

  static Future<int> packBytes(String journeyId) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/journey_tiles/$journeyId');
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final e in dir.list()) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  static Future<void> deletePack(String journeyId) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/journey_tiles/$journeyId');
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

/// The tiles covering a route corridor: every trail point's tile plus a
/// one-tile buffer, across the packed zoom range. This tracks the line (not
/// the whole bounding box), keeping packs small.
List<(int, int, int)> _corridorTiles(List<LatLng> trail) {
  final seen = <String>{};
  final tiles = <(int, int, int)>[];
  for (var z = _minPackZoom; z <= _maxPackZoom; z++) {
    final maxIndex = (1 << z) - 1;
    for (final p in trail) {
      final tx = _xTile(p.longitude, z);
      final ty = _yTile(p.latitude, z);
      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          final x = tx + dx, y = ty + dy;
          if (x < 0 || y < 0 || x > maxIndex || y > maxIndex) continue;
          final key = '$z/$x/$y';
          if (seen.add(key)) tiles.add((z, x, y));
        }
      }
    }
  }
  return tiles;
}

/// Download the offline pack for [journeyId] covering [trail]. Reports
/// (done, total) as it goes. Skips tiles already on disk (resumable).
Future<void> downloadJourneyCorridor(
  String journeyId,
  List<LatLng> trail, {
  void Function(int done, int total)? onProgress,
}) async {
  if (trail.length < 2) return;
  final dir = await OfflineTileStore.dirFor(journeyId);
  final tiles = _corridorTiles(trail);
  final dio = Dio();
  var done = 0;
  try {
    for (final (z, x, y) in tiles) {
      final file = OfflineTileStore.tileFile(dir, z, x, y);
      if (!await file.exists()) {
        try {
          final resp = await dio.get<List<int>>(
            _tileUrl(z, x, y),
            options: Options(
              responseType: ResponseType.bytes,
              validateStatus: (s) => s != null && s < 500,
            ),
          );
          // 200 = real tile; 204 = empty area (nothing to store).
          if (resp.statusCode == 200 && resp.data != null && resp.data!.isNotEmpty) {
            await file.writeAsBytes(resp.data!, flush: false);
          }
        } catch (_) {
          // Skip a tile that fails; the pack is best-effort.
        }
      }
      done++;
      onProgress?.call(done, tiles.length);
    }
  } finally {
    dio.close();
  }
}

/// A vmt provider that reads a journey's downloaded tiles first (offline), then
/// falls back to the network. Used by the follow map so a downloaded route
/// works with no signal.
class OfflineFirstVectorTileProvider extends VectorTileProvider {
  OfflineFirstVectorTileProvider({
    required this.journeyId,
    this.maximumZoom = _maxPackZoom,
    this.minimumZoom = 0,
  });

  final String journeyId;

  @override
  final int maximumZoom;
  @override
  final int minimumZoom;
  @override
  TileOffset get tileOffset => TileOffset.DEFAULT;
  @override
  TileProviderType get type => TileProviderType.vector;

  final Dio _dio = Dio();
  Directory? _dir;

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    _dir ??= await OfflineTileStore.dirFor(journeyId);
    final file = OfflineTileStore.tileFile(_dir!, tile.z, tile.x, tile.y);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    try {
      final resp = await _dio.get<List<int>>(
        _tileUrl(tile.z, tile.x, tile.y),
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      if (resp.statusCode == 200 && resp.data != null) {
        return Uint8List.fromList(resp.data!);
      }
      throw ProviderException(
        message: 'Tile ${tile.z}/${tile.x}/${tile.y}: HTTP ${resp.statusCode}',
        statusCode: resp.statusCode ?? 0,
        retryable: Retryable.none,
      );
    } on DioException catch (e) {
      throw ProviderException(message: e.message ?? 'offline', retryable: Retryable.retry);
    }
  }
}
