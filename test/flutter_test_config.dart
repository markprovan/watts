import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests normally render with the blocky Ahem font; load the real one so layout checks are meaningful.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bytes = await File('assets/fonts/RobotoFlex.ttf').readAsBytes();
  final loader = FontLoader('RobotoFlex')
    ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  await loader.load();
  await testMain();
}
