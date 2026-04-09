import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_payload.dart';

class OverlayWindowPayloadDto {
  const OverlayWindowPayloadDto({
    required this.sceneId,
    required this.displayMode,
  });

  final int sceneId;
  final String displayMode;

  OverlayWindowPayload toModel() {
    return OverlayWindowPayload(
      sceneId: sceneId,
      displayMode: displayMode,
    );
  }

  Map<String, dynamic> toRaw() {
    return <String, dynamic>{
      'sceneId': sceneId,
      'displayMode': displayMode,
    };
  }

  factory OverlayWindowPayloadDto.fromModel(OverlayWindowPayload payload) {
    return OverlayWindowPayloadDto(
      sceneId: payload.sceneId,
      displayMode: payload.displayMode,
    );
  }

  factory OverlayWindowPayloadDto.fromRaw(dynamic raw) {
    if (raw is OverlayWindowPayload) {
      return OverlayWindowPayloadDto.fromModel(raw);
    }

    if (raw is int) {
      return OverlayWindowPayloadDto(
        sceneId: raw,
        displayMode: OverlayWindowDisplayMode.bubble,
      );
    }

    if (raw is String) {
      final parsedScene = int.tryParse(raw);
      if (parsedScene != null) {
        return OverlayWindowPayloadDto(
          sceneId: parsedScene,
          displayMode: OverlayWindowDisplayMode.bubble,
        );
      }
    }

    if (raw is Map) {
      final normalized = raw.map(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      );
      final sceneValue = normalized['sceneId'] ?? normalized['scene'];
      final parsedScene = switch (sceneValue) {
        int value => value,
        String value => int.tryParse(value),
        _ => null,
      };
      if (parsedScene != null) {
        final rawDisplayMode = normalized['displayMode']?.toString();
        return OverlayWindowPayloadDto(
          sceneId: parsedScene,
          displayMode: rawDisplayMode == OverlayWindowDisplayMode.panel
              ? OverlayWindowDisplayMode.panel
              : OverlayWindowDisplayMode.bubble,
        );
      }
    }

    return const OverlayWindowPayloadDto(
      sceneId: 0,
      displayMode: OverlayWindowDisplayMode.bubble,
    );
  }
}
