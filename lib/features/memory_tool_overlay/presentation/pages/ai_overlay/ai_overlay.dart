import 'dart:ui';

import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/ai_overlay_collapsed_ball.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/overlay_window/presentation/providers/overlay_window_host_runtime_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AiOverlay extends HookConsumerWidget {
  const AiOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProcess = ref.watch(memoryToolSelectedProcessProvider);
    final isPanelVisible = ref.watch(
      overlayWindowHostRuntimeProvider.select(
        (state) => state.payload.isPanel && !state.isTransitioningToPanel,
      ),
    );

    if (!isPanelVisible || selectedProcess == null) {
      return const SizedBox.shrink();
    }

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final portraitTopInset = mediaQuery.orientation == Orientation.portrait
        ? mediaQuery.padding.top
        : 0.0;
    final isExpanded = useState(false);
    final offset = useState<Offset?>(null);
    final dragStartGlobal = useRef<Offset?>(null);
    final dragStartOffset = useRef<Offset?>(null);
    final collapsedDiameter = 44.r;
    final expandedSize = Size(236.r, 156.r);
    final safePadding = 12.r;

    Size currentSize() => isExpanded.value
        ? expandedSize
        : Size(collapsedDiameter, collapsedDiameter);

    Offset defaultOffset(Size size) =>
        Offset(screenSize.width - size.width - 20.r, portraitTopInset + 88.r);

    Offset clampOffset(Offset value, Size size) {
      final minX = safePadding;
      final maxX = (screenSize.width - size.width - safePadding).clamp(
        minX,
        double.infinity,
      );
      final minY = portraitTopInset + safePadding;
      final maxY = (screenSize.height - size.height - safePadding).clamp(
        minY,
        double.infinity,
      );
      return Offset(value.dx.clamp(minX, maxX), value.dy.clamp(minY, maxY));
    }

    useEffect(() {
      isExpanded.value = false;
      final size = Size(collapsedDiameter, collapsedDiameter);
      offset.value = clampOffset(defaultOffset(size), size);
      return null;
    }, [selectedProcess.pid]);

    useEffect(
      () {
        final size = currentSize();
        offset.value = clampOffset(offset.value ?? defaultOffset(size), size);
        return null;
      },
      [screenSize.width, screenSize.height, portraitTopInset, isExpanded.value],
    );

    final resolvedSize = currentSize();
    final resolvedOffset = clampOffset(
      offset.value ?? defaultOffset(resolvedSize),
      resolvedSize,
    );

    return Positioned(
      left: resolvedOffset.dx,
      top: resolvedOffset.dy,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (details) {
          dragStartGlobal.value = details.globalPosition;
          dragStartOffset.value = resolvedOffset;
        },
        onPanUpdate: (details) {
          final startGlobal = dragStartGlobal.value;
          final startOffset = dragStartOffset.value;
          if (startGlobal == null || startOffset == null) {
            return;
          }
          final delta = details.globalPosition - startGlobal;
          offset.value = clampOffset(startOffset + delta, resolvedSize);
        },
        onPanEnd: (_) {
          dragStartGlobal.value = null;
          dragStartOffset.value = null;
        },
        onPanCancel: () {
          dragStartGlobal.value = null;
          dragStartOffset.value = null;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: resolvedSize.width,
          height: resolvedSize.height,
          decoration: BoxDecoration(
            color: isExpanded.value
                ? context.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.76,
                  )
                : null,
            gradient: isExpanded.value
                ? null
                : RadialGradient(
                    center: Alignment.center,
                    radius: 0.95,
                    colors: <Color>[
                      context.colorScheme.primary,
                      Color.lerp(
                            context.colorScheme.primary,
                            context.colorScheme.primaryContainer,
                            0.58,
                          ) ??
                          context.colorScheme.primaryContainer,
                    ],
                    stops: const <double>[0.38, 1],
                  ),
            borderRadius: BorderRadius.circular(isExpanded.value ? 20.r : 14.r),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color:
                    (isExpanded.value
                            ? Colors.black
                            : context.colorScheme.primary)
                        .withValues(alpha: isExpanded.value ? 0.1 : 0.18),
                blurRadius: isExpanded.value ? 16.r : 10.r,
                offset: Offset(0, isExpanded.value ? 6.r : 4.r),
              ),
              if (!isExpanded.value)
                BoxShadow(
                  color: context.colorScheme.primary.withValues(alpha: 0.32),
                  blurRadius: 14.r,
                  spreadRadius: 1.2.r,
                ),
            ],
            border: Border.all(
              color: isExpanded.value
                  ? context.colorScheme.outlineVariant.withValues(alpha: 0.34)
                  : context.colorScheme.onPrimary.withValues(alpha: 0.22),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: isExpanded.value
              ? Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: ColoredBox(
                          color: context.colorScheme.surface.withValues(
                            alpha: 0.08,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(14.r, 12.r, 12.r, 12.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Material(
                            color: context.colorScheme.surface.withValues(
                              alpha: 0.28,
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12.r),
                              onTap: () => isExpanded.value = false,
                              child: Padding(
                                padding: EdgeInsets.all(4.r),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16.r,
                                  color: context.colorScheme.onSurface
                                      .withValues(alpha: 0.82),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : AiOverlayCollapsedBall(
                  onTap: () {
                    isExpanded.value = true;
                  },
                ),
        ),
      ),
    );
  }
}
