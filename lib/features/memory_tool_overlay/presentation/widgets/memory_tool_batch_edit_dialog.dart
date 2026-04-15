import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_action_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/utils/memory_tool_search_result_presenter.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_value_editor_dialog.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolBatchEditDialog extends HookConsumerWidget {
  const MemoryToolBatchEditDialog({
    super.key,
    required this.results,
    required this.livePreviewsAsync,
    required this.onClose,
  });

  final List<SearchResult> results;
  final AsyncValue<Map<int, MemoryValuePreview>> livePreviewsAsync;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedType = useState<SearchValueType>(
      results.isEmpty ? SearchValueType.i32 : results.first.type,
    );
    final valueController = useTextEditingController();
    final valueActionState = ref.watch(memoryValueActionProvider);
    useListenable(valueController);

    Future<void> handleSave() async {
      final sessionState = await ref.read(getSearchSessionStateProvider.future);
      final previewRequests = results
          .map((result) {
            final fallbackPreview =
                livePreviewsAsync.asData?.value[result.address];
            final bytesLength =
                fallbackPreview?.rawBytes.length ?? result.rawBytes.length;
            return MemoryReadRequest(
              address: result.address,
              type: selectedType.value,
              length: resolveMemoryToolReadLengthForType(
                type: selectedType.value,
                bytesLength: bytesLength,
              ),
            );
          })
          .toList(growable: false);
      final currentPreviews = await ref
          .read(memoryQueryRepositoryProvider)
          .readMemoryValues(requests: previewRequests);
      final currentPreviewByAddress = <int, MemoryValuePreview>{
        for (final preview in currentPreviews) preview.address: preview,
      };

      final requests = <MemoryWriteRequest>[];
      final previousPreviews = <MemoryValuePreview>[];
      for (final result in results) {
        final currentPreview = currentPreviewByAddress[result.address];
        if (currentPreview == null) {
          continue;
        }

        previousPreviews.add(currentPreview);
        requests.add(
          MemoryWriteRequest(
            address: result.address,
            value: buildMemoryToolWriteValue(
              type: selectedType.value,
              input: valueController.text,
              littleEndian: sessionState.littleEndian,
              sourceType: currentPreview.type,
              sourceRawBytes: currentPreview.rawBytes,
              sourceDisplayValue: currentPreview.displayValue,
            ),
          ),
        );
      }

      if (requests.isEmpty) {
        throw StateError('No readable selected results.');
      }

      await ref
          .read(memoryValueActionProvider.notifier)
          .writeMemoryValues(
            requests: requests,
            previousPreviews: previousPreviews,
          );

      if (!context.mounted) {
        return;
      }
      onClose();
    }

    final canSave =
        results.isNotEmpty &&
        valueController.text.trim().isNotEmpty &&
        !valueActionState.isLoading;
    final selectedTypeLabel = mapMemoryToolSearchResultTypeLabel(
      type: selectedType.value,
      displayValue: valueController.text,
    );

    return MemoryToolValueEditorDialog(
      title: context.l10n.memoryToolResultActionBatchEdit,
      subtitle:
          '${context.l10n.memoryToolSessionSelectedCount}: ${results.length}',
      selectedTypeLabel: selectedTypeLabel,
      typeLabelBuilder: (type) {
        return mapMemoryToolSearchResultTypeLabel(
          type: type,
          displayValue: type == SearchValueType.bytes
              ? valueController.text
              : '',
        );
      },
      onSelectedType: (value) {
        selectedType.value = value;
      },
      valueController: valueController,
      valueHintText: context.l10n.memoryToolFieldValuePlaceholder,
      errorText: valueActionState.error?.toString(),
      canSave: canSave,
      onSave: handleSave,
      onClose: onClose,
      maxWidthPortrait: 372,
      maxWidthLandscape: 430,
      maxHeightPortrait: 320,
      maxHeightLandscape: 300,
    );
  }
}
