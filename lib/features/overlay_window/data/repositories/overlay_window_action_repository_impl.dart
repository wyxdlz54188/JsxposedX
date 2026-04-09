import 'dart:io';
import 'dart:ui';

import 'package:JsxposedX/features/overlay_window/data/datasources/overlay_window_action_datasource.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_host_layout.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_payload.dart';
import 'package:JsxposedX/features/overlay_window/domain/repositories/overlay_window_action_repository.dart';
import 'package:flutter/foundation.dart';

class OverlayWindowActionRepositoryImpl
    implements OverlayWindowActionRepository {
  const OverlayWindowActionRepositoryImpl({
    required OverlayWindowActionDatasource dataSource,
  }) : _dataSource = dataSource;

  final OverlayWindowActionDatasource _dataSource;

  bool get _isSupportedPlatform => !kIsWeb && Platform.isAndroid;

  @override
  Future<bool> closeOverlay() async {
    if (!_isSupportedPlatform) {
      return false;
    }
    return _dataSource.closeOverlay();
  }

  @override
  Future<bool> moveOverlay(Offset position) async {
    if (!_isSupportedPlatform) {
      return false;
    }
    return _dataSource.moveOverlay(position);
  }

  @override
  Future<bool> requestPermission() async {
    if (!_isSupportedPlatform) {
      return false;
    }
    return _dataSource.requestPermission();
  }

  @override
  Future<void> sharePayload(OverlayWindowPayload payload) async {
    if (!_isSupportedPlatform) {
      return;
    }
    await _dataSource.sharePayload(payload);
  }

  @override
  Future<void> showOverlayHost({
    required OverlayHostLayout layout,
    required String notificationTitle,
    required String notificationContent,
  }) async {
    if (!_isSupportedPlatform) {
      return;
    }
    await _dataSource.showOverlayHost(
      layout: layout,
      notificationTitle: notificationTitle,
      notificationContent: notificationContent,
    );
  }

  @override
  Future<bool> updateOverlayHost(OverlayHostLayout layout) async {
    if (!_isSupportedPlatform) {
      return false;
    }
    return _dataSource.updateOverlayHost(layout);
  }
}
