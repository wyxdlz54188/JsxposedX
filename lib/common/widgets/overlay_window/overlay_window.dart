import 'dart:math' as math;

import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class OverlayWindow extends StatelessWidget {
  const OverlayWindow({
    super.key,
    required this.child,
    this.header,
    this.title,
    this.subtitle,
    this.onClose,
    this.onMinimize,
    this.onBackdropTap,
    this.footer,
    this.margin = const EdgeInsets.all(20),
    this.maxWidth = 560,
    this.maxHeight,
  });

  final Widget child;
  final Widget? header;
  final String? title;
  final String? subtitle;
  final VoidCallback? onClose;
  final VoidCallback? onMinimize;
  final VoidCallback? onBackdropTap;
  final Widget? footer;
  final EdgeInsetsGeometry margin;
  final double maxWidth;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final resolvedHeader = header ?? _buildHeader(context);
    final hasHeader = resolvedHeader != null;
    final colorScheme = context.colorScheme;
    final backdropTapHandler = onBackdropTap ?? onMinimize ?? onClose;

    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final resolvedMaxHeight = maxHeight == null
              ? constraints.maxHeight
              : math.min(maxHeight!, constraints.maxHeight);

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: backdropTapHandler,
                child: const _OverlayBackdrop(),
              ),
              SafeArea(
                child: Padding(
                  padding: margin,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxWidth,
                        maxHeight: resolvedMaxHeight,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.97),
                          borderRadius: BorderRadius.circular(24.r),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.42,
                            ),
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.24),
                              blurRadius: 20.r,
                              offset: Offset(0, 12.h),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(20.r),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                if (hasHeader) resolvedHeader,
                                if (hasHeader) SizedBox(height: 16.h),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.58),
                                    borderRadius: BorderRadius.circular(18.r),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(16.r),
                                    child: child,
                                  ),
                                ),
                                if (footer != null) ...<Widget>[
                                  SizedBox(height: 12.h),
                                  footer!,
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget? _buildHeader(BuildContext context) {
    if (title == null &&
        subtitle == null &&
        onClose == null &&
        onMinimize == null) {
      return null;
    }

    final colorScheme = context.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 42.w,
              height: 42.w,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: const Icon(
                Icons.memory_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (title != null)
                    Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (subtitle != null) ...<Widget>[
                    if (title != null) SizedBox(height: 4.h),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onMinimize != null) ...<Widget>[
              _OverlayHeaderButton(
                icon: Icons.remove_rounded,
                onPressed: onMinimize!,
              ),
              SizedBox(width: 8.w),
            ],
            if (onClose != null)
              _OverlayHeaderButton(
                icon: Icons.close_rounded,
                onPressed: onClose!,
              ),
          ],
        ),
      ),
    );
  }
}

class _OverlayBackdrop extends StatelessWidget {
  const _OverlayBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0x990B1020)),
      child: const SizedBox.expand(),
    );
  }
}

class _OverlayHeaderButton extends StatelessWidget {
  const _OverlayHeaderButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: onPressed,
        child: SizedBox(
          width: 40.w,
          height: 40.w,
          child: Icon(icon, size: 20.sp, color: colorScheme.onSurface),
        ),
      ),
    );
  }
}
