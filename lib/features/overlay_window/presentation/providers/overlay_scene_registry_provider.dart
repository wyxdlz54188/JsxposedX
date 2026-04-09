import 'package:JsxposedX/features/memory_tool_overlay/presentation/overlay/memory_tool_overlay_scene.dart';
import 'package:JsxposedX/features/overlay_window/presentation/models/overlay_scene_definition.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'overlay_scene_registry_provider.g.dart';

@riverpod
Map<int, OverlaySceneDefinition> overlaySceneRegistry(Ref ref) {
  return <int, OverlaySceneDefinition>{
    MemoryToolOverlayScene.sceneId: MemoryToolOverlayScene.definition,
  };
}
