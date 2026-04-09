import 'dart:ui';

import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_event.dart';

class OverlayWindowEventDto {
  const OverlayWindowEventDto({
    required this.type,
    this.hostPosition,
  });

  final String type;
  final Offset? hostPosition;

  OverlayWindowEvent toModel() {
    return OverlayWindowEvent(type: type, hostPosition: hostPosition);
  }

  static OverlayWindowEvent? maybeFromRaw(dynamic raw) {
    if (raw is! Map) {
      return null;
    }

    final normalized = raw.map(
      (Object? key, Object? value) => MapEntry(key.toString(), value),
    );
    final eventType = normalized['event']?.toString();
    if (eventType == null) {
      return null;
    }

    switch (eventType) {
      case OverlayWindowEventType.bubbleTap:
        return const OverlayWindowEvent(type: OverlayWindowEventType.bubbleTap);
      case OverlayWindowEventType.bubbleDragEnd:
        final x = _parseDouble(normalized['x']);
        final y = _parseDouble(normalized['y']);
        if (x == null || y == null) {
          return null;
        }
        return OverlayWindowEvent(
          type: OverlayWindowEventType.bubbleDragEnd,
          hostPosition: Offset(x, y),
        );
      default:
        return null;
    }
  }

  static double? _parseDouble(Object? value) {
    return switch (value) {
      int number => number.toDouble(),
      double number => number,
      String text => double.tryParse(text),
      _ => null,
    };
  }
}
