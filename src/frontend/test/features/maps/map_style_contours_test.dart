import 'dart:convert';
import 'dart:io';

import 'package:carnine_frontend/features/maps/presentation/maps_content.dart';
import 'package:flutter_test/flutter_test.dart';

/// The contour lines of local_map 0.12.0 in the CarNine style: a source of
/// their own, marked so it never comes from the map file, and layers that
/// stay under buildings, roads and labels.
void main() {
  final style =
      jsonDecode(File('assets/maps/style_carnine_dark.json').readAsStringSync())
          as Map<String, dynamic>;
  final layers = (style['layers'] as List).cast<Map<String, dynamic>>();
  List<String> ids() => [for (final layer in layers) layer['id'] as String];

  test('the contour source is an extra source, never the map', () {
    final source =
        (style['sources'] as Map<String, dynamic>)['contours']
            as Map<String, dynamic>;
    expect(source['local_map:extra'], isTrue);
    expect(source['type'], 'vector');
    expect(
      MapsContent.extraVectorSources.keys,
      contains('contours'),
      reason: 'the style source and the file mapping use the same name',
    );
  });

  test('contour lines lie under buildings and roads, heights under names', () {
    final order = ids();
    final contours = [
      for (final layer in layers)
        if (layer['source'] == 'contours') layer['id'] as String,
    ];
    expect(contours, ['contour-minor', 'contour-major', 'contour-label']);
    for (final layer in layers.where((l) => l['source'] == 'contours')) {
      expect(layer['source-layer'], 'contour');
    }
    expect(order.indexOf('contour-major'), lessThan(order.indexOf('building')));
    expect(
      order.indexOf('contour-major'),
      lessThan(order.indexOf('transportation-path')),
    );
    final firstSymbol = layers.indexWhere((l) => l['type'] == 'symbol');
    expect(
      order[firstSymbol],
      'contour-label',
      reason: 'street and place names are drawn after it',
    );
  });

  test('the style id and version changed with the new layers', () {
    // vector_map_tiles caches filtered tile data under the id and rendered
    // tiles under id and metadata.version; without a change the map would
    // show the old style.
    expect(style['id'], 'carnine-dark-3');
    expect((style['metadata'] as Map<String, dynamic>)['version'], '4');
  });
}
