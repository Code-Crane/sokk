import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const referenceCapture = bool.fromEnvironment('REFERENCE_CAPTURE');

Future<void> loadReferenceFonts() async {
  if (!referenceCapture) return;
  await (FontLoader('ReferenceQA')
        ..addFont(File('C:/Windows/Fonts/malgun.ttf')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes))))
      .load();
  await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
      .load();
}

Future<void> captureReference(
    WidgetTester tester, Finder boundary, String name) async {
  if (!referenceCapture) return;
  // Wait for actual bundled PNG decoding before capturing the test render.
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final widget = element.widget as Image;
      await precacheImage(widget.image, element);
    }
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final render = tester.renderObject<RenderRepaintBoundary>(boundary);
    final image = await render.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/reference_qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
