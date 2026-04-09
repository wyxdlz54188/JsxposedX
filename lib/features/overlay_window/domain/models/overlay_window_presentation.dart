class OverlayWindowPresentation {
  const OverlayWindowPresentation({
    this.width,
    this.height,
    this.bubbleSize = defaultBubbleSize,
    this.enableDrag = true,
    this.notificationTitle,
    this.notificationContent,
  });

  static const double defaultBubbleSize = 58;

  final double? width;
  final double? height;
  final double bubbleSize;
  final bool enableDrag;
  final String? notificationTitle;
  final String? notificationContent;
}
