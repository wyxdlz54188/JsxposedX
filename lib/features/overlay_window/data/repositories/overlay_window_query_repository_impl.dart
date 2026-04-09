import 'dart:io';
import 'dart:ui';

import 'package:JsxposedX/features/overlay_window/data/datasources/overlay_window_query_datasource.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_viewport_metrics_model.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_status.dart';
import 'package:JsxposedX/features/overlay_window/domain/repositories/overlay_window_query_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class OverlayWindowQueryRepositoryImpl implements OverlayWindowQueryRepository {
  const OverlayWindowQueryRepositoryImpl({
    required OverlayWindowQueryDatasource dataSource,
  }) : _dataSource = dataSource;

  final OverlayWindowQueryDatasource _dataSource;

  @override
  bool get isSupportedPlatform => !kIsWeb && Platform.isAndroid;

  @override
  Stream<dynamic> get overlayEvents => _dataSource.overlayEvents;

  @override
  Future<bool> isActive() async {
    if (!isSupportedPlatform) {
      return false;
    }
    return _dataSource.isActive();
  }

  @override
  Future<bool> isPermissionGranted() async {
    if (!isSupportedPlatform) {
      return false;
    }
    return _dataSource.isPermissionGranted();
  }

  @override
  Future<Offset> getOverlayPosition() async {
    if (!isSupportedPlatform) {
      return Offset.zero;
    }
    return _dataSource.getOverlayPosition();
  }

  @override
  Future<OverlayViewportMetricsModel> getOverlayViewportMetrics() async {
    if (!isSupportedPlatform) {
      return const OverlayViewportMetricsModel(
        width: 0,
        height: 0,
        safePadding: EdgeInsets.zero,
      );
    }
    return _dataSource.getOverlayViewportMetrics();
  }

  @override
  Future<OverlayWindowStatus> getStatus() async {
    if (!isSupportedPlatform) {
      return const OverlayWindowStatus(
        isSupported: false,
        hasPermission: false,
        isActive: false,
      );
    }

    final hasPermission = await isPermissionGranted();
    final active = await isActive();
    return OverlayWindowStatus(
      isSupported: true,
      hasPermission: hasPermission,
      isActive: active,
    );
  }
}
