import 'dart:async';
import 'dart:ui';

import 'package:JsxposedX/features/overlay_window/domain/models/overlay_viewport_metrics_model.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_status.dart';

abstract class OverlayWindowQueryRepository {
  bool get isSupportedPlatform;

  Stream<dynamic> get overlayEvents;

  Future<bool> isPermissionGranted();

  Future<bool> isActive();

  Future<Offset> getOverlayPosition();

  Future<OverlayViewportMetricsModel> getOverlayViewportMetrics();

  Future<OverlayWindowStatus> getStatus();
}
