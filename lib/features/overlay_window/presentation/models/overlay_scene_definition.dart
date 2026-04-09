import 'package:flutter/widgets.dart';

typedef OverlaySceneTextBuilder = String Function(BuildContext context);
typedef OverlaySceneWidgetBuilder = Widget Function(BuildContext context);

class OverlaySceneDefinition {
  const OverlaySceneDefinition({
    required this.sceneId,
    required this.bubbleSize,
    required this.title,
    this.subtitle,
    required this.notificationTitle,
    required this.notificationContent,
    required this.panelBuilder,
  });

  final int sceneId;
  final double bubbleSize;
  final OverlaySceneTextBuilder title;
  final OverlaySceneTextBuilder? subtitle;
  final OverlaySceneTextBuilder notificationTitle;
  final OverlaySceneTextBuilder notificationContent;
  final OverlaySceneWidgetBuilder panelBuilder;
}
