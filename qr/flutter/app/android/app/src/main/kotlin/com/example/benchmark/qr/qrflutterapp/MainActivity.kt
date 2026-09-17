package com.example.benchmark.qr.qrflutterapp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    // The benchmark markers Dart reports are written to logcat here.
    BenchMarker.register(flutterEngine.dartExecutor.binaryMessenger)
  }
}
