import 'dart:ui';

class OverlayHostLayout {
  const OverlayHostLayout({
    required this.width,
    required this.height,
    required this.position,
    required this.enableDrag,
    required this.displayMode,
  });

  final int width;
  final int height;
  final Offset position;
  final bool enableDrag;
  final String displayMode;
}
