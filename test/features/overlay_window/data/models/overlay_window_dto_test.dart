import 'dart:ui';

import 'package:JsxposedX/features/overlay_window/data/models/overlay_window_event_dto.dart';
import 'package:JsxposedX/features/overlay_window/data/models/overlay_window_payload_dto.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_event.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OverlayWindowPayloadDto', () {
    test('parses payload map and serializes back', () {
      final dto = OverlayWindowPayloadDto.fromRaw(
        <String, dynamic>{
          'sceneId': 7,
          'displayMode': OverlayWindowDisplayMode.panel,
        },
      );

      expect(dto.sceneId, 7);
      expect(dto.displayMode, OverlayWindowDisplayMode.panel);
      expect(dto.toModel().sceneId, 7);
      expect(dto.toRaw(), <String, dynamic>{
        'sceneId': 7,
        'displayMode': OverlayWindowDisplayMode.panel,
      });
    });

    test('supports legacy scene field', () {
      final dto = OverlayWindowPayloadDto.fromRaw(
        <String, dynamic>{'scene': '5'},
      );

      expect(dto.sceneId, 5);
      expect(dto.displayMode, OverlayWindowDisplayMode.bubble);
    });
  });

  group('OverlayWindowEventDto', () {
    test('parses bubble tap event', () {
      final event = OverlayWindowEventDto.maybeFromRaw(
        <String, dynamic>{'event': OverlayWindowEventType.bubbleTap},
      );

      expect(event, isNotNull);
      expect(event!.isBubbleTap, isTrue);
      expect(event.hostPosition, isNull);
    });

    test('parses drag end event with host position', () {
      final event = OverlayWindowEventDto.maybeFromRaw(
        <String, dynamic>{
          'event': OverlayWindowEventType.bubbleDragEnd,
          'x': '12.5',
          'y': 30,
        },
      );

      expect(event, isNotNull);
      expect(event!.isBubbleDragEnd, isTrue);
      expect(event.hostPosition, const Offset(12.5, 30));
    });
  });
}
