import 'dart:async';

import 'package:carnine_frontend/features/maps/data/map_follow_zoom_store.dart';

/// Hand-written [MapFollowZoomStore] for tests: keeps the level in memory like
/// the backend does (0 = never saved). [saves] records every save.
class FakeMapFollowZoomStore implements MapFollowZoomStore {
  FakeMapFollowZoomStore({this.zoom = 0});

  int zoom;

  /// Thrown by loading while it is set, to play a backend that is not up yet.
  Object? loadError;

  /// Thrown by the next save, once.
  Object? saveError;

  /// Holds loading until completed.
  Completer<void>? loadGate;

  int loads = 0;
  final List<int> saves = [];

  @override
  Future<int> loadFollowZoom() async {
    loads++;
    await loadGate?.future;
    final failure = loadError;
    if (failure != null) {
      throw failure;
    }
    return zoom;
  }

  @override
  Future<void> saveFollowZoom(int level) async {
    saves.add(level);
    final failure = saveError;
    if (failure != null) {
      saveError = null;
      throw failure;
    }
    zoom = level;
  }
}
