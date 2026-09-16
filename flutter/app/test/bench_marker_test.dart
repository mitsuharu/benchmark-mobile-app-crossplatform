import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterapp/src/bench_marker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(BenchMarker.channelName);
  late List<MethodCall> sent;

  setUp(() {
    sent = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          sent.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('sends a marker with the time it was taken', () async {
    final before = DateTime.now().millisecondsSinceEpoch;

    BenchMarker().mark('searchTapped');
    await pumpEventQueue();

    final arguments = sent.single.arguments as Map;
    expect(sent.single.method, 'mark');
    expect(arguments['name'], 'searchTapped');
    expect(arguments['epochMs'], greaterThanOrEqualTo(before));
  });

  test('sends the time it is given rather than now', () async {
    final at = DateTime.fromMillisecondsSinceEpoch(1700000000000);

    BenchMarker().mark('searchTapped', at: at);
    await pumpEventQueue();

    expect((sent.single.arguments as Map)['epochMs'], 1700000000000);
  });

  testWidgets('marks after the frame has been drawn', (tester) async {
    BenchMarker().markAfterFrame('searchRendered');

    expect(sent, isEmpty);
    await tester.pumpWidget(const SizedBox());
    // pumpEventQueue hangs inside testWidgets' fake clock; idle() is enough to
    // let the channel call reach the mock handler.
    await tester.idle();

    expect(sent.single.method, 'mark');
    expect((sent.single.arguments as Map)['name'], 'searchRendered');
  });

  testWidgets('asks the native side for processStart on a launch mark', (
    tester,
  ) async {
    BenchMarker().markAfterFrame('homeFirstFrame', launch: true);

    await tester.pumpWidget(const SizedBox());
    await tester.idle();

    expect(sent.single.method, 'markLaunch');
    expect((sent.single.arguments as Map)['name'], 'homeFirstFrame');
  });
}
