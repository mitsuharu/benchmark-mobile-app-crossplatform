import 'dart:async';

import 'package:flutter/material.dart';

import 'src/bench_marker.dart';
import 'src/decoder.dart';
import 'src/qr_images.dart';

/// How often the screen redraws while decoding; see AGENTS.md.
const _progressInterval = Duration(milliseconds: 100);

void main() => runApp(const QrBenchmarkApp());

/// The QR decode benchmark, written entirely in Flutter: unpack the bundled
/// images, then decode them one after the other with mobile_scanner.
class QrBenchmarkApp extends StatelessWidget {
  const QrBenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'QR デコード',
      debugShowCheckedModeBanner: false,
      home: QrScreen(),
    );
  }
}

enum _Phase { preparing, ready, running, done, failed }

class QrScreen extends StatefulWidget {
  const QrScreen({super.key, this.marker});

  final BenchMarker? marker;

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  _Phase _phase = _Phase.preparing;
  List<String> _paths = const [];
  String? _error;

  final _progress = DecodeProgress();
  Timer? _ticker;
  int _done = 0;
  Duration _elapsed = Duration.zero;

  int _decoded = 0;
  int _totalMs = 0;
  double _perImageMs = 0;

  BenchMarker get _marker => widget.marker ?? BenchMarker.instance;

  @override
  void initState() {
    super.initState();
    _marker.markLaunchAfterFrame();
    unawaited(_prepare());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      final paths = await unpackImages();
      if (!mounted) return;
      setState(() {
        _paths = paths;
        _phase = _Phase.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _phase = _Phase.failed;
      });
    }
  }

  Future<void> _start() async {
    _progress.current = 0;
    setState(() {
      _done = 0;
      _elapsed = Duration.zero;
      _phase = _Phase.running;
    });

    final startedAt = DateTime.now();
    _ticker = Timer.periodic(_progressInterval, (_) {
      if (!mounted) return;
      setState(() {
        _done = _progress.current;
        _elapsed = DateTime.now().difference(startedAt);
      });
    });

    try {
      final run = await decodeAll(_paths, _progress);
      // Written now that the loop is over, so logging stays out of the
      // measurement (see AGENTS.md).
      _marker.mark('decodeStarted', at: run.startedAt);
      _marker.mark('decodeFinished', at: run.finishedAt);
      _marker.markValue('decodedCount', '${run.decoded}');
      _marker.markValue('decodeDurationsUs', run.durationsUs.join(','));

      final sorted = [...run.durationsUs]..sort();
      if (!mounted) return;
      setState(() {
        _decoded = run.decoded;
        _totalMs = run.finishedAt.difference(run.startedAt).inMilliseconds;
        _perImageMs = sorted[sorted.length ~/ 2] / 1000;
        _done = run.durationsUs.length;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _phase = _Phase.failed;
      });
    } finally {
      _ticker?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('QR デコード', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 4),
              const Text(
                'Flutter · mobile_scanner',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 12),
              if (_phase == _Phase.preparing)
                const Text('画像を展開中...')
              else if (_phase == _Phase.failed)
                Text('失敗: $_error', style: const TextStyle(color: Colors.red))
              else
                Text('準備完了: ${_paths.length} 枚'),
              const SizedBox(height: 12),
              if (_phase == _Phase.ready || _phase == _Phase.done)
                Semantics(
                  identifier: 'startDecode',
                  child: FilledButton(
                    onPressed: _start,
                    child: const Text('デコードを開始'),
                  ),
                ),
              if (_phase == _Phase.running) ...[
                Text(
                  'デコード中: $_done / ${_paths.length}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '経過: ${(_elapsed.inMilliseconds / 1000).toStringAsFixed(1)} 秒',
                ),
              ],
              if (_phase == _Phase.done) ...[
                const SizedBox(height: 12),
                Text(
                  'デコード完了: $_decoded / ${_paths.length}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text('合計: $_totalMs ms'),
                Text('1 枚あたり: ${_perImageMs.toStringAsFixed(2)} ms'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
