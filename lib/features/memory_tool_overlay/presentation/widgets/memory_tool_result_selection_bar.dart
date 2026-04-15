import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MemoryToolResultSelectionBar extends StatelessWidget {
  const MemoryToolResultSelectionBar({
    super.key,
    required this.hasVisibleResults,
    required this.hasSelection,
    required this.canRestorePrevious,
    required this.onSelectAll,
    required this.onInvert,
    required this.onClear,
    required this.onOpenBatchEdit,
    required this.onRestorePrevious,
    required this.onOpenSettings,
    required this.onOpenSearch,
  });

  final bool hasVisibleResults;
  final bool hasSelection;
  final bool canRestorePrevious;
  final VoidCallback onSelectAll;
  final VoidCallback onInvert;
  final VoidCallback onClear;
  final VoidCallback onOpenBatchEdit;
  final VoidCallback onRestorePrevious;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 6.r),
        child: Row(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.42,
                ),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.r, vertical: 2.r),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _MemoryToolResultSelectionAction(
                      icon: Icons.search_rounded,
                      onTap: onOpenSearch,
                    ),
                    const _MemoryToolResultSelectionDivider(),
                    _MemoryToolResultSelectionAction(
                      icon: Icons.done_all_rounded,
                      onTap: hasVisibleResults ? onSelectAll : null,
                    ),
                    const _MemoryToolResultSelectionDivider(),
                    _MemoryToolResultSelectionAction(
                      icon: Icons.flip_rounded,
                      onTap: hasVisibleResults ? onInvert : null,
                    ),
                    const _MemoryToolResultSelectionDivider(),
                    _MemoryToolResultSelectionAction(
                      icon: Icons.layers_clear_rounded,
                      onTap: hasVisibleResults ? onClear : null,
                    ),
                    const _MemoryToolResultSelectionDivider(),
                    _MemoryToolResultSelectionAction(
                      icon: Icons.edit_rounded,
                      onTap: hasSelection ? onOpenBatchEdit : null,
                    ),
                    const _MemoryToolResultSelectionDivider(),
                    _MemoryToolResultSelectionAction(
                      icon: Icons.undo_rounded,
                      onTap: canRestorePrevious ? onRestorePrevious : null,
                    ),
                    const _MemoryToolResultSelectionDivider(),
                    _MemoryToolResultSelectionAction(
                      icon: Icons.tune_rounded,
                      onTap: onOpenSettings,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _MemoryToolResultSelectionDivider extends StatelessWidget {
  const _MemoryToolResultSelectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18.r,
      margin: EdgeInsets.symmetric(horizontal: 2.r),
      color: context.colorScheme.outlineVariant.withValues(alpha: 0.52),
    );
  }
}

class _MemoryToolResultSelectionAction extends StatelessWidget {
  const _MemoryToolResultSelectionAction({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8.r),
      onTap: onTap,
      child: SizedBox(
        width: 28.r,
        height: 28.r,
        child: Center(
          child: Icon(
            icon,
            size: 18.r,
            color: context.colorScheme.onSurface.withValues(
              alpha: onTap == null ? 0.3 : 0.76,
            ),
          ),
        ),
      ),
    );
  }
}
