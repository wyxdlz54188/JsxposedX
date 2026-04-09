import 'dart:ui';

class OverlayWindowEventType {
  static const String bubbleTap = 'bubbleTap';
  static const String bubbleDragEnd = 'bubbleDragEnd';
}

class OverlayWindowEvent {
  const OverlayWindowEvent({
    required this.type,
    this.hostPosition,
  });

  final String type;
  final Offset? hostPosition;

  bool get isBubbleTap => type == OverlayWindowEventType.bubbleTap;
  bool get isBubbleDragEnd => type == OverlayWindowEventType.bubbleDragEnd;
}
