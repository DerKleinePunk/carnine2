import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Frontend logging facade with an in-memory buffer for the UI log viewer.
///
/// Logs are written to `logs/frontend.log` during local development. The
/// backend forwarding described in the architecture docs can be added behind
/// this facade without touching widgets.
abstract final class AppLogging {
  const AppLogging._();

  static const int maxBufferedLines = 200;
  static final Logger frontend = Logger('CarnineFrontend');

  static final ValueNotifier<List<String>> _lines = ValueNotifier<List<String>>(
    <String>[],
  );

  static IOSink? _sink;
  static bool _initialized = false;
  static StreamSubscription<LogRecord>? _subscription;

  /// Serializes every disk write. `IOSink.flush()` binds the sink until its
  /// future completes (`dart:io`'s `_StreamSinkImpl._isBound`), so writing a
  /// new line while a previous line's flush is still pending throws
  /// `Bad state: StreamSink is bound to a stream`. Chaining through this
  /// future guarantees line N's write+flush finishes before line N+1
  /// starts, however fast records arrive.
  static Future<void> _pendingWrite = Future<void>.value();

  /// Recent formatted log lines for widgets that render diagnostics.
  static ValueListenable<List<String>> get lines => _lines;

  /// Configures root logging once and appends records to disk and DevTools.
  static Future<void> initialize({String? logPath}) async {
    if (_initialized) {
      return;
    }

    final resolvedLogPath =
        logPath ??
        Platform.environment['CARNINE_LOG_PATH'] ??
        'logs/frontend.log';
    final file = File(resolvedLogPath);
    await file.parent.create(recursive: true);

    _sink = file.openWrite(mode: FileMode.append);
    Logger.root.level = Level.ALL;
    _subscription = Logger.root.onRecord.listen(_handleRecord);
    _initialized = true;
  }

  /// Releases file handles, mainly useful for tests and controlled shutdowns.
  static Future<void> shutdown() async {
    await _subscription?.cancel();
    // Wait for any in-flight write+flush before closing - closing while the
    // sink is still bound to a flush throws the same "bound to a stream"
    // state error as writing would.
    await _pendingWrite;
    await _sink?.close();

    _subscription = null;
    _sink = null;
    _initialized = false;
  }

  static void _handleRecord(LogRecord record) {
    final line = _formatRecord(record);

    _appendBufferedLine(line);
    _writeLine(line);
    _sendToDeveloperLog(record);
  }

  static String _formatRecord(LogRecord record) {
    final message = StringBuffer()
      ..write(record.time.toIso8601String())
      ..write(' [${record.level.name}] ')
      ..write(record.loggerName)
      ..write(': ')
      ..write(record.message);

    final error = record.error;
    if (error != null) {
      message.write(' | error=$error');
    }

    final stackTrace = record.stackTrace;
    if (stackTrace != null) {
      message.write('\n$stackTrace');
    }

    return message.toString();
  }

  static void _appendBufferedLine(String line) {
    final nextLines = <String>[..._lines.value, line];
    final overflow = nextLines.length - maxBufferedLines;

    if (overflow > 0) {
      nextLines.removeRange(0, overflow);
    }

    _lines.value = List<String>.unmodifiable(nextLines);
  }

  static void _writeLine(String line) {
    final sink = _sink;
    if (sink == null) {
      return;
    }

    _pendingWrite = _pendingWrite
        .then((_) async {
          sink.writeln(line);
          await sink.flush();
        })
        .catchError((_) {
          // A broken log write must never crash the app or wedge the chain for
          // subsequent lines.
        });
  }

  static void _sendToDeveloperLog(LogRecord record) {
    developer.log(
      record.message,
      time: record.time,
      sequenceNumber: record.sequenceNumber,
      level: record.level.value,
      name: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  }
}
