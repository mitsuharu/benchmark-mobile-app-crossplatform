import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Emits the benchmark markers described in AGENTS.md.
///
/// Dart takes the timestamps, and the native side of the app writes them to
/// the platform log in the same `BENCH|<name>|<epochMs>` form every
/// implementation uses — the runner reads the app log, which Dart's own
/// `print` does not reliably reach in a release build.
class BenchMarker {
  BenchMarker({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'bench/marker';

  /// The one the app uses. Tests build their own with a fake channel.
  static BenchMarker instance = BenchMarker();

  final MethodChannel _channel;

  void mark(String name, {DateTime? at}) {
    _send('mark', name, at);
  }

  /// Marks once the frame being built has been drawn.
  ///
  /// With `launch: true` the native side also emits `processStart`, the one
  /// marker Dart cannot know.
  void markAfterFrame(String name, {bool launch = false}) {
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => _send(launch ? 'markLaunch' : 'mark', name, null),
    );
  }

  void _send(String method, String name, DateTime? at) {
    // Nothing on the native side answers with a value; the call is
    // fire-and-forget so it cannot hold up the frame being measured.
    unawaited(
      _channel.invokeMethod<void>(method, {
        'name': name,
        'epochMs': (at ?? DateTime.now()).millisecondsSinceEpoch,
      }),
    );
  }
}
