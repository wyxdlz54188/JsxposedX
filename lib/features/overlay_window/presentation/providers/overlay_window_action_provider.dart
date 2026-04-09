import 'dart:ui';

import 'package:JsxposedX/features/overlay_window/data/datasources/overlay_window_action_datasource.dart';
import 'package:JsxposedX/features/overlay_window/data/repositories/overlay_window_action_repository_impl.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_host_layout.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_payload.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_presentation.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_status.dart';
import 'package:JsxposedX/features/overlay_window/domain/repositories/overlay_window_action_repository.dart';
import 'package:JsxposedX/features/overlay_window/presentation/models/overlay_scene_definition.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_scene_registry_provider.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_window_query_provider.dart';
import 'package:JsxposedX/features/overlay_window/presentation/utils/overlay_window_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'overlay_window_action_provider.g.dart';

@riverpod
OverlayWindowActionDatasource overlayWindowActionDatasource(Ref ref) {
  final gateway = ref.watch(overlayWindowPlatformGatewayProvider);
  return OverlayWindowActionDatasource(gateway: gateway);
}

@riverpod
OverlayWindowActionRepository overlayWindowActionRepository(Ref ref) {
  final dataSource = ref.watch(overlayWindowActionDatasourceProvider);
  return OverlayWindowActionRepositoryImpl(dataSource: dataSource);
}

@Riverpod(keepAlive: true)
class OverlayWindowAction extends _$OverlayWindowAction {
  Offset? _lastBubbleVisualOffset;

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<OverlayWindowStatus> show(
    BuildContext context, {
    required int sceneId,
    OverlayWindowPresentation presentation =
        const OverlayWindowPresentation(),
  }) async {
    state = const AsyncValue.loading();
    try {
      final scene = _readScene(sceneId);
      if (scene == null) {
        debugPrint('Unknown overlay sceneId: $sceneId');
        return await _refreshStatus();
      }

      var currentStatus = await _refreshStatus();
      if (!currentStatus.isSupported) {
        return currentStatus;
      }

      if (!currentStatus.hasPermission) {
        await ref.read(overlayWindowActionRepositoryProvider).requestPermission();
        currentStatus = await _refreshStatus();
        if (!currentStatus.hasPermission) {
          return currentStatus;
        }
      }

      final resolvedPresentation = OverlayWindowPresentation(
        width: presentation.width,
        height: presentation.height,
        bubbleSize: scene.bubbleSize,
        enableDrag: presentation.enableDrag,
        notificationTitle:
            presentation.notificationTitle ?? scene.notificationTitle(context),
        notificationContent: presentation.notificationContent ??
            scene.notificationContent(context),
      );
      final bubbleLayout = await _resolveBubbleLayout(
        scene: scene,
        presentation: resolvedPresentation,
      );

      if (currentStatus.isActive) {
        await ref.read(overlayWindowActionRepositoryProvider).updateOverlayHost(
              bubbleLayout,
            );
      } else {
        await ref.read(overlayWindowActionRepositoryProvider).showOverlayHost(
              layout: bubbleLayout,
              notificationTitle: resolvedPresentation.notificationTitle!,
              notificationContent: resolvedPresentation.notificationContent!,
            );
      }

      _lastBubbleVisualOffset = OverlayWindowGeometry.visualOffsetFromHostPosition(
        bubbleLayout.position,
      );
      await ref.read(overlayWindowActionRepositoryProvider).sharePayload(
            OverlayWindowPayload(
              sceneId: sceneId,
              displayMode: OverlayWindowDisplayMode.bubble,
            ),
          );
      return await _refreshStatus();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    } finally {
      if (!state.hasError) {
        state = const AsyncValue.data(null);
      }
    }
  }

  Future<OverlayWindowStatus> expand({required int sceneId}) async {
    state = const AsyncValue.loading();
    try {
      final scene = _readScene(sceneId);
      if (scene == null) {
        debugPrint('Unknown overlay sceneId: $sceneId');
        return await _refreshStatus();
      }

      final currentStatus = await _refreshStatus();
      if (!currentStatus.isActive) {
        return currentStatus;
      }

      await ref.read(overlayWindowActionRepositoryProvider).updateOverlayHost(
            const OverlayHostLayout(
              width: WindowSize.matchParent,
              height: WindowSize.fullCover,
              position: Offset.zero,
              enableDrag: false,
              displayMode: OverlayWindowDisplayMode.panel,
            ),
          );
      await ref.read(overlayWindowActionRepositoryProvider).sharePayload(
            OverlayWindowPayload(
              sceneId: scene.sceneId,
              displayMode: OverlayWindowDisplayMode.panel,
            ),
          );
      return await _refreshStatus();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    } finally {
      if (!state.hasError) {
        state = const AsyncValue.data(null);
      }
    }
  }

  Future<OverlayWindowStatus> collapse({
    required int sceneId,
    OverlayWindowPresentation presentation =
        const OverlayWindowPresentation(),
  }) async {
    state = const AsyncValue.loading();
    try {
      final scene = _readScene(sceneId);
      if (scene == null) {
        debugPrint('Unknown overlay sceneId: $sceneId');
        return await _refreshStatus();
      }

      final currentStatus = await _refreshStatus();
      if (!currentStatus.isActive) {
        return currentStatus;
      }

      final bubbleLayout = await _resolveBubbleLayout(
        scene: scene,
        presentation: OverlayWindowPresentation(
          width: presentation.width,
          height: presentation.height,
          bubbleSize: scene.bubbleSize,
          enableDrag: presentation.enableDrag,
          notificationTitle: presentation.notificationTitle,
          notificationContent: presentation.notificationContent,
        ),
      );
      await ref.read(overlayWindowActionRepositoryProvider).updateOverlayHost(
            bubbleLayout,
          );
      _lastBubbleVisualOffset = OverlayWindowGeometry.visualOffsetFromHostPosition(
        bubbleLayout.position,
      );
      await ref.read(overlayWindowActionRepositoryProvider).sharePayload(
            OverlayWindowPayload(
              sceneId: scene.sceneId,
              displayMode: OverlayWindowDisplayMode.bubble,
            ),
          );
      return await _refreshStatus();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    } finally {
      if (!state.hasError) {
        state = const AsyncValue.data(null);
      }
    }
  }

  Future<OverlayWindowStatus> hide() async {
    state = const AsyncValue.loading();
    try {
      await ref.read(overlayWindowActionRepositoryProvider).closeOverlay();
      return await _refreshStatus();
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    } finally {
      if (!state.hasError) {
        state = const AsyncValue.data(null);
      }
    }
  }

  OverlaySceneDefinition? _readScene(int sceneId) {
    return ref.read(overlaySceneRegistryProvider)[sceneId];
  }

  Future<OverlayWindowStatus> _refreshStatus() {
    ref.invalidate(overlayWindowStatusProvider);
    return ref.read(overlayWindowStatusProvider.future);
  }

  Future<OverlayHostLayout> _resolveBubbleLayout({
    required OverlaySceneDefinition scene,
    required OverlayWindowPresentation presentation,
  }) async {
    final viewport = await ref
        .read(overlayWindowQueryRepositoryProvider)
        .getOverlayViewportMetrics();
    final visualOffset = OverlayWindowGeometry.clampBubbleVisualOffset(
      _lastBubbleVisualOffset ??
          OverlayWindowGeometry.defaultBubbleVisualOffset(
            viewport: viewport,
            bubbleSize: scene.bubbleSize,
          ),
      viewport: viewport,
      bubbleSize: scene.bubbleSize,
    );
    final bubbleHostExtent = OverlayWindowGeometry.bubbleHostExtent(
      presentation.bubbleSize,
    );
    return OverlayHostLayout(
      width: (presentation.width ?? bubbleHostExtent).round(),
      height: (presentation.height ?? bubbleHostExtent).round(),
      position: OverlayWindowGeometry.hostPositionFromVisualOffset(visualOffset),
      enableDrag: presentation.enableDrag,
      displayMode: OverlayWindowDisplayMode.bubble,
    );
  }
}
