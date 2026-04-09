class OverlayWindowDisplayMode {
  static const String bubble = 'bubble';
  static const String panel = 'panel';
}

class OverlayWindowPayload {
  const OverlayWindowPayload({
    required this.sceneId,
    this.displayMode = OverlayWindowDisplayMode.bubble,
  });

  final int sceneId;
  final String displayMode;

  bool get isBubble => displayMode == OverlayWindowDisplayMode.bubble;
  bool get isPanel => displayMode == OverlayWindowDisplayMode.panel;

  OverlayWindowPayload copyWith({int? sceneId, String? displayMode}) {
    return OverlayWindowPayload(
      sceneId: sceneId ?? this.sceneId,
      displayMode: displayMode ?? this.displayMode,
    );
  }
}
