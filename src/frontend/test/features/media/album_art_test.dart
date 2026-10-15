import 'dart:typed_data';

import 'package:carnine_frontend/features/media/presentation/widgets/player/album_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A cover is decoded at the size it is shown: a 1000 px cover would be
  // 4 MB decoded, also for the 72 px tile of the start page.
  for (final ratio in const [1.0, 2.0]) {
    testWidgets('the cover is decoded at its shown width, ratio $ratio', (
      tester,
    ) async {
      tester.view.devicePixelRatio = ratio;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: AlbumArt(size: 72, coverArt: Uint8List.fromList([1, 2])),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image)).image;
      expect(image, isA<ResizeImage>());
      expect((image as ResizeImage).width, (72 * ratio).ceil());
      expect(image.height, isNull);
    });
  }
}
