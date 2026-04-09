import 'dart:ui';

import 'package:JsxposedX/features/overlay_window/data/datasources/overlay_window_platform_gateway.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_viewport_metrics_model.dart';
import 'package:flutter/widgets.dart';

class OverlayWindowQueryDatasource {
  const OverlayWindowQueryDatasource({
    required OverlayWindowPlatformGateway gateway,
  }) : _gateway = gateway;

  final OverlayWindowPlatformGateway _gateway;

  Stream<dynamic> get overlayEvents => _gateway.overlayListener;

  Future<bool> isPermissionGranted() => _gateway.isPermissionGranted();

  Future<bool> isActive() => _gateway.isActive();

  Future<Offset> getOverlayPosition() async {
    final position = await _gateway.getOverlayPosition();
    return Offset(position.x, position.y);
  }

  Future<OverlayViewportMetricsModel> getOverlayViewportMetrics() async {
    final metrics = await _gateway.getOverlayViewportMetrics();
    return OverlayViewportMetricsModel(
      width: metrics.width,
      height: metrics.height,
      safePadding: EdgeInsets.fromLTRB(
        metrics.safeLeft,
        metrics.safeTop,
        metrics.safeRight,
        metrics.safeBottom,
      ),
    );
  }
}
