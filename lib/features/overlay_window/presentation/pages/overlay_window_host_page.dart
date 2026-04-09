import 'dart:async';
import 'dart:ui';

import 'package:JsxposedX/common/widgets/overlay_window/overlay_bubble.dart';
import 'package:JsxposedX/common/widgets/overlay_window/overlay_window.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/overlay_window/data/models/overlay_window_event_dto.dart';
import 'package:JsxposedX/features/overlay_window/data/models/overlay_window_payload_dto.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_event.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_payload.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_presentation.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_viewport_metrics_model.dart';
import 'package:JsxposedX/features/overlay_window/presentation/models/overlay_scene_definition.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_app_payload_provider.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_scene_registry_provider.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_window_query_provider.dart';
import 'package:JsxposedX/features/overlay_window/presentation/utils/overlay_window_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class OverlayWindowHostPage extends ConsumerStatefulWidget {
  const OverlayWindowHostPage({super.key});

  @override
  ConsumerState<OverlayWindowHostPage> createState() =>
      _OverlayWindowHostPageState();
}

class _OverlayWindowHostPageState extends ConsumerState<OverlayWindowHostPage>
    with WidgetsBindingObserver {
  static const double _panelMaxWidth = 560;
  static const double _panelMaxHeight = 720;

  StreamSubscription<dynamic>? _subscription;
  late OverlayWindowPayload _payload;
  OverlayViewportMetricsModel? _viewportMetrics;
  Offset? _bubbleVisualOffset;
  bool _isTransitioningToPanel = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _payload = OverlayWindowPayload(sceneId: _defaultSceneId());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(overlayAppPayloadProvider.notifier).setPayload(_payload);
    });
    _subscription = ref
        .read(overlayWindowQueryRepositoryProvider)
        .overlayEvents
        .listen(_handlePayload);
    unawaited(_refreshViewportMetrics(syncBubblePosition: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    unawaited(
      _refreshViewportMetrics(
        syncBubblePosition: _payload.isBubble && !_isTransitioningToPanel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: _isTransitioningToPanel
          ? const SizedBox.expand()
          : _payload.isPanel
          ? _buildPanelWindow(context)
          : _buildBubble(),
    );
  }

  int _defaultSceneId() {
    final registry = ref.read(overlaySceneRegistryProvider);
    if (registry.isEmpty) {
      return -1;
    }
    return registry.keys.first;
  }

  OverlaySceneDefinition? _scene(int sceneId) {
    return ref.read(overlaySceneRegistryProvider)[sceneId];
  }

  void _handlePayload(dynamic rawPayload) {
    final overlayEvent = OverlayWindowEventDto.maybeFromRaw(rawPayload);
    if (overlayEvent != null) {
      _handleOverlayEvent(overlayEvent);
      return;
    }

    final nextPayload = OverlayWindowPayloadDto.fromRaw(rawPayload).toModel();
    if (!mounted) {
      return;
    }

    setState(() {
      _payload = nextPayload;
    });
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      ref.read(overlayAppPayloadProvider.notifier).setPayload(nextPayload);
    });

    if (nextPayload.isBubble && !_isTransitioningToPanel) {
      unawaited(_syncBubbleVisualOffsetFromHost());
    }
  }

  void _handleOverlayEvent(OverlayWindowEvent event) {
    if (!mounted || !_payload.isBubble || _isTransitioningToPanel) {
      return;
    }

    if (event.isBubbleTap) {
      unawaited(_setDisplayMode(OverlayWindowDisplayMode.panel));
      return;
    }

    if (!event.isBubbleDragEnd) {
      return;
    }

    final hostPosition = event.hostPosition;
    final viewport = _viewportMetrics;
    if (hostPosition == null || viewport == null) {
      return;
    }

    final bubbleSize = _bubbleSizeForScene(_payload.sceneId);
    final visualOffset = OverlayWindowGeometry.visualOffsetFromHostPosition(
      hostPosition,
    );
    final snappedVisualOffset = OverlayWindowGeometry.snapBubbleVisualOffset(
      visualOffset,
      viewport: viewport,
      bubbleSize: bubbleSize,
    );

    setState(() {
      _bubbleVisualOffset = snappedVisualOffset;
    });
    unawaited(_moveBubbleHostToVisualOffset(snappedVisualOffset));
  }

  Future<void> _setDisplayMode(String displayMode) async {
    if (_payload.displayMode == displayMode) {
      return;
    }

    if (displayMode == OverlayWindowDisplayMode.panel) {
      setState(() {
        _isTransitioningToPanel = true;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return;
      }

      final updated = await FlutterOverlayWindow.updateOverlayLayout(
        width: WindowSize.matchParent,
        height: WindowSize.fullCover,
        position: const OverlayPosition(0, 0),
        enableDrag: false,
        flag: OverlayFlag.defaultFlag,
      );
      if (!mounted) {
        return;
      }
      if (updated != true) {
        setState(() {
          _isTransitioningToPanel = false;
        });
        return;
      }

      final nextPayload = _payload.copyWith(
        displayMode: OverlayWindowDisplayMode.panel,
      );
      setState(() {
        _isTransitioningToPanel = false;
        _payload = nextPayload;
      });
      Future<void>.microtask(() {
        if (!mounted) {
          return;
        }
        ref.read(overlayAppPayloadProvider.notifier).setPayload(nextPayload);
      });
      unawaited(_broadcastPayload(nextPayload));
      return;
    }

    final viewport = await _ensureViewportMetrics();
    if (!mounted || viewport == null) {
      return;
    }

    final bubbleSize = _bubbleSizeForScene(_payload.sceneId);
    final bubbleVisualOffset = OverlayWindowGeometry.clampBubbleVisualOffset(
      _bubbleVisualOffset ??
          OverlayWindowGeometry.defaultBubbleVisualOffset(
            viewport: viewport,
            bubbleSize: bubbleSize,
          ),
      viewport: viewport,
      bubbleSize: bubbleSize,
    );

    final updated = await FlutterOverlayWindow.updateOverlayLayout(
      width: OverlayWindowGeometry.bubbleHostExtent(bubbleSize).round(),
      height: OverlayWindowGeometry.bubbleHostExtent(bubbleSize).round(),
      position: OverlayPosition(
        OverlayWindowGeometry.hostPositionFromVisualOffset(bubbleVisualOffset).dx,
        OverlayWindowGeometry.hostPositionFromVisualOffset(bubbleVisualOffset).dy,
      ),
      enableDrag: true,
      flag: OverlayFlag.focusPointer,
    );
    if (!mounted || updated != true) {
      return;
    }

    final nextPayload = _payload.copyWith(
      displayMode: OverlayWindowDisplayMode.bubble,
    );
    setState(() {
      _bubbleVisualOffset = bubbleVisualOffset;
      _payload = nextPayload;
    });
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      ref.read(overlayAppPayloadProvider.notifier).setPayload(nextPayload);
    });
    unawaited(_broadcastPayload(nextPayload));
  }

  Widget _buildPanelWindow(BuildContext context) {
    final scene = _scene(_payload.sceneId);
    final title =
        scene?.title(context) ?? context.l10n.overlayWindowFallbackTitle;
    final subtitle =
        scene?.subtitle?.call(context) ??
        context.l10n.overlayFloatingToolWindow;

    return OverlayWindow(
      title: title,
      subtitle: subtitle,
      onBackdropTap: () => _setDisplayMode(OverlayWindowDisplayMode.bubble),
      onMinimize: () => _setDisplayMode(OverlayWindowDisplayMode.bubble),
      onClose: () {
        unawaited(FlutterOverlayWindow.closeOverlay());
      },
      maxWidth: _panelMaxWidth,
      maxHeight: _panelMaxHeight,
      child: scene?.panelBuilder(context) ?? _buildUnknownScene(context),
    );
  }

  Widget _buildBubble() {
    return SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.all(OverlayWindowGeometry.bubbleHostPadding),
        child: OverlayBubble(size: _bubbleSizeForScene(_payload.sceneId)),
      ),
    );
  }

  Widget _buildUnknownScene(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.overlayWindowUnknownSceneTitle,
          style: context.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          context.l10n.overlayWindowUnknownSceneDescription,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        SizedBox(height: 16.h),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () {
              unawaited(FlutterOverlayWindow.closeOverlay());
            },
            child: Text(context.l10n.close),
          ),
        ),
      ],
    );
  }

  Future<OverlayViewportMetricsModel?> _ensureViewportMetrics() async {
    if (_viewportMetrics != null) {
      return _viewportMetrics;
    }
    return _refreshViewportMetrics(syncBubblePosition: false);
  }

  Future<OverlayViewportMetricsModel?> _refreshViewportMetrics({
    required bool syncBubblePosition,
  }) async {
    final viewport = await ref
        .read(overlayWindowQueryRepositoryProvider)
        .getOverlayViewportMetrics();
    if (!mounted) {
      return viewport;
    }

    setState(() {
      _viewportMetrics = viewport;
      if (_bubbleVisualOffset != null && !_isTransitioningToPanel) {
        final bubbleSize = _bubbleSizeForScene(_payload.sceneId);
        _bubbleVisualOffset = OverlayWindowGeometry.clampBubbleVisualOffset(
          _bubbleVisualOffset!,
          viewport: viewport,
          bubbleSize: bubbleSize,
        );
      }
    });

    if (syncBubblePosition && _payload.isBubble && !_isTransitioningToPanel) {
      await _syncBubbleVisualOffsetFromHost();
    }
    return viewport;
  }

  Future<void> _syncBubbleVisualOffsetFromHost() async {
    final viewport = await _ensureViewportMetrics();
    if (!mounted || viewport == null) {
      return;
    }

    final bubbleSize = _bubbleSizeForScene(_payload.sceneId);
    final hostPosition = await ref
        .read(overlayWindowQueryRepositoryProvider)
        .getOverlayPosition();
    final visualOffset = OverlayWindowGeometry.clampBubbleVisualOffset(
      OverlayWindowGeometry.visualOffsetFromHostPosition(hostPosition),
      viewport: viewport,
      bubbleSize: bubbleSize,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _bubbleVisualOffset = visualOffset;
    });
  }

  Future<void> _moveBubbleHostToVisualOffset(Offset bubbleVisualOffset) async {
    final hostPosition = OverlayWindowGeometry.hostPositionFromVisualOffset(
      bubbleVisualOffset,
    );
    await FlutterOverlayWindow.moveOverlay(
      OverlayPosition(hostPosition.dx, hostPosition.dy),
    );
  }

  Future<void> _broadcastPayload(OverlayWindowPayload payload) {
    return FlutterOverlayWindow.shareData(
      OverlayWindowPayloadDto.fromModel(payload).toRaw(),
    );
  }

  double _bubbleSizeForScene(int sceneId) {
    return _scene(sceneId)?.bubbleSize ??
        OverlayWindowPresentation.defaultBubbleSize;
  }
}
