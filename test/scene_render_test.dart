import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pescar_delta/widgets/delta_scene.dart';

/// Randează peisajul în PNG (doar când e setat SCENE_OUT) pentru verificare vizuală.
void main() {
  final out = Platform.environment['SCENE_OUT'];
  for (final t in SceneTime.values) {
    testWidgets('scena ${t.name} se desenează', (tester) async {
      final key = GlobalKey();
      tester.view.physicalSize = const Size(820, 340);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        RepaintBoundary(key: key, child: DeltaScene(time: t)),
      );
      if (out == null) return;
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$out/${t.name}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    });
  }
}
