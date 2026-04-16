import 'package:JsxposedX/common/widgets/loading.dart';
import 'package:JsxposedX/common/widgets/ref_error.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_batch_edit_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_tool_search_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_selection_dialog.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_selection_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_stats_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_search_result_list.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolSearchResultCard extends HookConsumerWidget {
  const MemoryToolSearchResultCard({
    super.key,
    required this.hasMatchingSession,
    required this.sessionStateAsync,
    required this.onRetry,
    required this.onOpenSearch,
  });

  final bool hasMatchingSession;
  final AsyncValue<SearchSessionState> sessionStateAsync;
  final VoidCallback onRetry;
  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectionState = ref.watch(memoryToolResultSelectionProvider);
    final selectionNotifier = ref.read(
      memoryToolResultSelectionProvider.notifier,
    );
    final livePreviewsAsync = ref.watch(
      currentSearchResultLivePreviewsProvider,
    );
    final valueHistoryState = ref.watch(memoryValueHistoryProvider);
    final removedResultState = ref.watch(memoryToolRemovedResultProvider);
    final removedResultNotifier = ref.read(
      memoryToolRemovedResultProvider.notifier,
    );
    final selectedPid = ref.watch(memoryToolSelectedProcessProvider)?.pid;
    final isSettingsVisible = useState(false);
    final isBatchEditVisible = useState(false);

    final resultsAsync = hasMatchingSession
        ? ref.watch(currentSearchResultsProvider)
        : const AsyncValue.data(<SearchResult>[]);
    final displayedResults = resultsAsync.maybeWhen(
      data: (results) => results,
      orElse: () => const <SearchResult>[],
    );
    final resultCount = sessionStateAsync.maybeWhen(
      data: (state) {
        final removedCount = removedResultState.removedAddresses.length;
        if (state.resultCount <= removedCount) {
          return 0;
        }
        return state.resultCount - removedCount;
      },
      orElse: () => displayedResults.length,
    );
    final pageCount = selectionState.selectionLimit <= 0
        ? 0
        : (resultCount / selectionState.selectionLimit).ceil();
    final visibleResults = displayedResults
        .take(selectionState.selectionLimit)
        .toList(growable: false);
    final selectedResults = visibleResults
        .where((result) => selectionState.contains(result.address))
        .toList(growable: false);
    final canRestorePrevious = selectionState.selectedAddresses.any(
      valueHistoryState.containsKey,
    );
    final previousValueByAddress = <int, String>{
      for (final entry in valueHistoryState.entries)
        entry.key: entry.value.displayValue,
    };
    final listStorageKey = PageStorageKey<String>(
      'memory_tool_search_results_${selectedPid ?? 0}',
    );

    return Stack(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 2.r),
          child: Column(
            children: <Widget>[
              MemoryToolResultSelectionBar(
                hasVisibleResults: visibleResults.isNotEmpty,
                hasSelection: selectedResults.isNotEmpty,
                canRestorePrevious: canRestorePrevious,
                onSelectAll: () {
                  selectionNotifier.selectVisible(visibleResults);
                },
                onInvert: () {
                  selectionNotifier.invertVisible(visibleResults);
                },
                onClear: selectionNotifier.clear,
                onDeleteSelected: () {
                  removedResultNotifier.removeMany(
                    selectionState.selectedAddresses,
                  );
                  selectionNotifier.clear();
                },
                onOpenBatchEdit: () {
                  isBatchEditVisible.value = true;
                },
                onRestorePrevious: () async {
                  try {
                    final sessionState = await ref.read(
                      getSearchSessionStateProvider.future,
                    );
                    await ref
                        .read(memoryValueActionProvider.notifier)
                        .restorePreviousValues(
                          addresses: selectionState.selectedAddresses,
                          littleEndian: sessionState.littleEndian,
                        );
                  } catch (error) {
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                },
                onOpenSettings: () {
                  isSettingsVisible.value = true;
                },
                onOpenSearch: onOpenSearch,
              ),
              SizedBox(height: 1.r),
              Expanded(
                child: !hasMatchingSession
                    ? _MemoryToolSearchEmptyState(message: context.l10n.noData)
                    : resultsAsync.when(
                        data: (_) {
                          if (visibleResults.isEmpty) {
                            return _MemoryToolSearchEmptyState(
                              message: context.l10n.noData,
                            );
                          }

                          return MemoryToolSearchResultList(
                            listStorageKey: listStorageKey,
                            results: visibleResults,
                            selectionState: selectionState,
                            selectionNotifier: selectionNotifier,
                            livePreviewsAsync: livePreviewsAsync,
                            previousValueByAddress: previousValueByAddress,
                          );
                        },
                        error: (error, _) =>
                            RefError(onRetry: onRetry, error: error),
                        loading: () {
                          if (visibleResults.isNotEmpty) {
                            return MemoryToolSearchResultList(
                              listStorageKey: listStorageKey,
                              results: visibleResults,
                              selectionState: selectionState,
                              selectionNotifier: selectionNotifier,
                              livePreviewsAsync: livePreviewsAsync,
                              previousValueByAddress: previousValueByAddress,
                            );
                          }

                          return const Loading();
                        },
                      ),
              ),
              SizedBox(height: 6.r),
              MemoryToolResultStatsBar(
                resultCount: resultCount,
                selectedCount: selectionState.selectedCount,
                renderedCount: visibleResults.length,
                pageCount: pageCount,
              ),
            ],
          ),
        ),
        if (isSettingsVisible.value)
          Positioned.fill(
            child: MemoryToolResultSelectionDialog(
              initialLimit: selectionState.selectionLimit,
              onClose: () {
                isSettingsVisible.value = false;
              },
              onConfirm: (value) {
                selectionNotifier.updateSelectionLimit(value);
                isSettingsVisible.value = false;
              },
            ),
          ),
        if (isBatchEditVisible.value)
          Positioned.fill(
            child: MemoryToolBatchEditDialog(
              results: selectedResults,
              livePreviewsAsync: livePreviewsAsync,
              onClose: () {
                isBatchEditVisible.value = false;
              },
            ),
          ),
      ],
    );
  }
}

class _MemoryToolSearchEmptyState extends StatelessWidget {
  const _MemoryToolSearchEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colorScheme.onSurface.withValues(alpha: 0.66),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
