import 'package:flutter/widgets.dart';

class OverlayViewportMetricsModel {
  const OverlayViewportMetricsModel({
    required this.width,
    required this.height,
    required this.safePadding,
  });

  final double width;
  final double height;
  final EdgeInsets safePadding;

  Size get size => Size(width, height);
}
