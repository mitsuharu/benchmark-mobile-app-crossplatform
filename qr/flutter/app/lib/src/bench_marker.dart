import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Emits the benchmark markers described in AGENTS.md.
///
/// Dart takes the timestamps, and the native side of the app writes them to
/// the platform log — Dart's own `print` does not reliably reach the app log
/// in a release build, which is what the runner reads.
class BenchMarker {
  BenchMarker({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'bench/marker';

  /// The one the app uses. Tests build their own with a fake channel.
  static BenchMarker instance = BenchMarker();

  final MethodChannel _channel;

  void mark(String name, {DateTime? at}) {
    _send('mark', {
      'name': name,
      'epochMs': (at ?? DateTime.now()).millisecondsSinceEpoch,
    });
  }

  /// Reports a figure rather than a time, such as the per-image durations.
  void markValue(String name, String value) {
    _send('markValue', {'name': name, 'value': value});
  }

  /// Marks the first frame once it has been drawn. The native side adds
  /// `processStart`, the one marker Dart cannot know.
  void markLaunchAfterFrame() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _send('markLaunch', {
        'name': 'homeFirstFrame',
        'epochMs': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  void _send(String method, Map<String, Object?> arguments) {
    // Nothing on the native side answers with a value; the call is
    // fire-and-forget.
    unawaited(_channel.invokeMethod<void>(method, arguments));
  }
}
