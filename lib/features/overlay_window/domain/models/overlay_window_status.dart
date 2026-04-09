class OverlayWindowStatus {
  const OverlayWindowStatus({
    required this.isSupported,
    required this.hasPermission,
    required this.isActive,
  });

  final bool isSupported;
  final bool hasPermission;
  final bool isActive;

  bool get canShow => isSupported && hasPermission;
}
