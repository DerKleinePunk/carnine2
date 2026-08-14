import 'dart:async';

import 'package:carnine_frontend/features/media/presentation/models/media_track.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

/// Presentation controller for the media player's playback UI state.
///
/// The frontend has no media backend yet (`docs/05-building-block.md`), so
/// this only tracks local playback/seek state for the mocked queue below.
class MediaController extends ChangeNotifier {
  MediaController({Logger? logger})
      : _logger = logger ?? Logger('MediaController') {
    if (_isPlaying) {
      _startTicker();
    }
  }

  static const List<MediaTrack> queue = <MediaTrack>[
    MediaTrack(
      title: 'Neon Dreams',
      artist: 'Cyberpunk Orchestra',
      album: 'The Void Within',
      releaseYear: 2024,
      duration: Duration(minutes: 4, seconds: 56),
    ),
    MediaTrack(
      title: 'Synthetic Rain',
      artist: 'Glitch Void',
      album: 'Synthetic Rain',
      releaseYear: 2024,
      duration: Duration(minutes: 3, seconds: 22),
    ),
    MediaTrack(
      title: 'Laser Focus',
      artist: 'Pulse Architect',
      album: 'Laser Focus',
      releaseYear: 2024,
      duration: Duration(minutes: 5, seconds: 10),
    ),
  ];

  static const Duration seekStep = Duration(seconds: 30);

  final Logger _logger;

  Timer? _ticker;
  bool _isPlaying = true;
  bool _isQueueExpanded = true;
  bool _isShuffleEnabled = false;
  bool _isRepeatEnabled = false;
  MediaLibraryAction? _openLibraryAction;
  Duration _position = const Duration(minutes: 2, seconds: 14);

  bool get isPlaying => _isPlaying;
  bool get isQueueExpanded => _isQueueExpanded;
  bool get isShuffleEnabled => _isShuffleEnabled;
  bool get isRepeatEnabled => _isRepeatEnabled;
  MediaLibraryAction? get openLibraryAction => _openLibraryAction;
  Duration get position => _position;
  MediaTrack get currentTrack => queue.first;

  /// Shows or hides the queue sidebar, giving the player core more room.
  void toggleQueueExpanded() {
    _isQueueExpanded = !_isQueueExpanded;
    _logger.info(
        _isQueueExpanded ? 'Queue panel expanded' : 'Queue panel collapsed');
    notifyListeners();
  }

  /// Opens the mock-up page for a library quick action (Create/Collections).
  void showLibraryAction(MediaLibraryAction action) {
    if (action == _openLibraryAction) {
      return;
    }

    _openLibraryAction = action;
    _logger.info('Opening media library action ${action.name}');
    notifyListeners();
  }

  /// Returns from the library action mock-up page to the player.
  void closeLibraryAction() {
    final current = _openLibraryAction;
    if (current == null) {
      return;
    }

    _openLibraryAction = null;
    _logger.info('Closing media library action ${current.name}');
    notifyListeners();
  }

  /// Toggles shuffle (random) playback order.
  void toggleShuffle() {
    _isShuffleEnabled = !_isShuffleEnabled;
    _logger.info(_isShuffleEnabled ? 'Shuffle enabled' : 'Shuffle disabled');
    notifyListeners();
  }

  /// Toggles repeat playback.
  void toggleRepeat() {
    _isRepeatEnabled = !_isRepeatEnabled;
    _logger.info(_isRepeatEnabled ? 'Repeat enabled' : 'Repeat disabled');
    notifyListeners();
  }

  /// Toggles between playing and paused, driving the play/pause button icon
  /// and starting/stopping the once-a-second playback ticker.
  void togglePlayback() {
    _isPlaying = !_isPlaying;
    if (_isPlaying) {
      _startTicker();
    } else {
      _stopTicker();
    }

    _logger.info(_isPlaying ? 'Playback resumed' : 'Playback paused');
    notifyListeners();
  }

  /// Seeks the current track by [offset], clamped to the track's bounds.
  void seekBy(Duration offset) {
    _position = _clamped(_position + offset);
    _logger.info('Seeked to ${_position.inSeconds}s');
    notifyListeners();
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _tick() {
    final next = _position + const Duration(seconds: 1);
    if (next >= currentTrack.duration) {
      _position = currentTrack.duration;
      _isPlaying = false;
      _stopTicker();
    } else {
      _position = next;
    }

    notifyListeners();
  }

  Duration _clamped(Duration target) {
    final upperBound = currentTrack.duration;
    return target < Duration.zero
        ? Duration.zero
        : (target > upperBound ? upperBound : target);
  }
}

/// Library quick actions surfaced below the queue, each opening its own
/// mock-up page until the actual feature exists.
enum MediaLibraryAction {
  create,
  collections,
}
