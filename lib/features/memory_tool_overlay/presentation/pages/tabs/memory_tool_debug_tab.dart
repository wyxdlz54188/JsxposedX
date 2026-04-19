import 'dart:async';
import 'dart:typed_data';

import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_breakpoint_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_selection_bar.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/widgets/memory_tool_result_stats_bar.dart';
import 'package:JsxposedX/generated/memory_tool.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolDebugTab extends HookConsumerWidget {
  const MemoryToolDebugTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedProcess = ref.watch(memoryToolSelectedProcessProvider);
    final pid = selectedProcess?.pid;
    final selectedBreakpointId = ref.watch(memoryBreakpointSelectedIdProvider);
    final breakpointActionState = ref.watch(memoryBreakpointActionProvider);
    final selectedWriterKey = useState<String?>(null);
    final compactTabController = useTabController(initialLength: 3);
    final landscapeDetailTabController = useTabController(initialLength: 2);
    final stateAsync = pid == null
        ? AsyncValue<MemoryBreakpointState>.data(
            MemoryBreakpointState(
              isSupported: true,
              isProcessPaused: false,
              activeBreakpointCount: 0,
              pendingHitCount: 0,
              architecture: '',
              lastError: '',
            ),
          )
        : ref.watch(getMemoryBreakpointStateProvider(pid: pid));
    final breakpointsAsync = pid == null
        ? const AsyncValue<List<MemoryBreakpoint>>.data(<MemoryBreakpoint>[])
        : ref.watch(getMemoryBreakpointsProvider(pid: pid));
    final hitsAsync = pid == null
        ? const AsyncValue<List<MemoryBreakpointHit>>.data(<MemoryBreakpointHit>[])
        : ref.watch(getMemoryBreakpointHitsProvider(pid: pid));
    final breakpoints = breakpointsAsync.asData?.value ?? const <MemoryBreakpoint>[];
    final allHits = hitsAsync.asData?.value ?? const <MemoryBreakpointHit>[];

    useEffect(() {
      selectedWriterKey.value = null;
      compactTabController.index = 0;
      landscapeDetailTabController.index = 0;
      return null;
    }, [pid]);

    useEffect(() {
      if (pid == null) {
        return null;
      }
      final timer = Timer.periodic(const Duration(milliseconds: 700), (_) {
        ref.invalidate(getMemoryBreakpointStateProvider(pid: pid));
        ref.invalidate(getMemoryBreakpointsProvider(pid: pid));
        ref.invalidate(getMemoryBreakpointHitsProvider(pid: pid));
      });
      return timer.cancel;
    }, [pid]);

    useEffect(() {
      if (pid == null) {
        return null;
      }
      if (breakpoints.isEmpty) {
        if (selectedBreakpointId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(memoryBreakpointSelectedIdProvider.notifier).clear();
          });
        }
        return null;
      }
      final hasSelection = breakpoints.any(
        (breakpoint) => breakpoint.id == selectedBreakpointId,
      );
      if (!hasSelection) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref
              .read(memoryBreakpointSelectedIdProvider.notifier)
              .set(breakpoints.first.id);
        });
      }
      return null;
    }, [pid, breakpoints, selectedBreakpointId]);

    final selectedBreakpoint = _resolveSelectedBreakpoint(
      breakpoints: breakpoints,
      selectedBreakpointId: selectedBreakpointId,
    );
    final hits = selectedBreakpoint == null
        ? const <MemoryBreakpointHit>[]
        : allHits
              .where((hit) => hit.breakpointId == selectedBreakpoint.id)
              .toList(growable: false);
    final writerGroups = _buildWriterGroups(hits);

    useEffect(() {
      if (pid == null) {
        return null;
      }
      final currentKey = selectedWriterKey.value;
      if (writerGroups.isEmpty) {
        if (currentKey != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            selectedWriterKey.value = null;
          });
        }
        return null;
      }
      final hasSelection = writerGroups.any((group) => group.key == currentKey);
      if (!hasSelection) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          selectedWriterKey.value = writerGroups.first.key;
        });
      }
      return null;
    }, [pid, selectedBreakpoint?.id, writerGroups, selectedWriterKey.value]);

    final selectedWriterGroup = _resolveSelectedWriterGroup(
      groups: writerGroups,
      selectedWriterKey: selectedWriterKey.value,
    );
    final state = stateAsync.asData?.value;
    final isPaused = state?.isProcessPaused ?? false;

    if (pid == null) {
      return Padding(
        padding: EdgeInsets.all(12.r),
        child: const _DebugProcessEmptyState(),
      );
    }

    Future<void> refreshAll() async {
      ref.invalidate(getMemoryBreakpointStateProvider(pid: pid));
      ref.invalidate(getMemoryBreakpointsProvider(pid: pid));
      ref.invalidate(getMemoryBreakpointHitsProvider(pid: pid));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final isWide = constraints.maxWidth >= 1280 && constraints.maxHeight >= 480;
        final isMedium = constraints.maxWidth >= 760;
        final isShortHeight = constraints.maxHeight < 320;
        final useLandscapeWorkbench = isLandscape && isMedium && !isWide;
        final outerSpacing = isShortHeight ? 6.r : 8.r;
        final workbenchPadding = isShortHeight ? 8.r : 10.r;

        final breakpointPanel = _DebugSection(
          title: context.isZh ? '断点列表' : 'Breakpoints',
          child: _BreakpointList(
            breakpointsAsync: breakpointsAsync,
            selectedBreakpointId: selectedBreakpoint?.id,
            onSelect: (breakpointId) {
              ref
                  .read(memoryBreakpointSelectedIdProvider.notifier)
                  .set(breakpointId);
              if (useLandscapeWorkbench) {
                landscapeDetailTabController.animateTo(0);
              } else if (!isMedium) {
                compactTabController.animateTo(1);
              }
            },
            onToggleEnabled: (breakpoint) async {
              await ref
                  .read(memoryBreakpointActionProvider.notifier)
                  .setMemoryBreakpointEnabled(
                    pid: pid,
                    breakpointId: breakpoint.id,
                    enabled: !breakpoint.enabled,
                  );
            },
            onRemove: (breakpoint) async {
              await ref
                  .read(memoryBreakpointActionProvider.notifier)
                  .removeMemoryBreakpoint(
                    pid: pid,
                    breakpointId: breakpoint.id,
                  );
            },
          ),
        );

        final writerPanel = _DebugSection(
          title: context.isZh ? '写入源' : 'Writers',
          child: _WriterGroupList(
            groups: writerGroups,
            selectedWriterKey: selectedWriterKey.value,
            onSelectWriter: (group) {
              selectedWriterKey.value = group.key;
              if (useLandscapeWorkbench) {
                landscapeDetailTabController.animateTo(1);
              } else if (!isMedium) {
                compactTabController.animateTo(2);
              }
            },
          ),
        );

        final detailPanel = _DebugSection(
          title: context.isZh ? '详情' : 'Detail',
          child: _WriterDetail(
            group: selectedWriterGroup,
            breakpoint: selectedBreakpoint,
          ),
        );

        final body = isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(flex: 9, child: breakpointPanel),
                  _PanelDivider(vertical: true),
                  Expanded(flex: 10, child: writerPanel),
                  _PanelDivider(vertical: true),
                  Expanded(flex: 11, child: detailPanel),
                ],
              )
            : useLandscapeWorkbench
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        flex: constraints.maxWidth >= 960 ? 8 : 9,
                        child: breakpointPanel,
                      ),
                      _PanelDivider(vertical: true),
                      Expanded(
                        flex: constraints.maxWidth >= 960 ? 14 : 12,
                        child: _LandscapeDetailWorkbench(
                          controller: landscapeDetailTabController,
                          writerPanel: writerPanel,
                          detailPanel: detailPanel,
                        ),
                      ),
                    ],
                  )
                : isMedium
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Expanded(flex: 9, child: breakpointPanel),
                          _PanelDivider(vertical: true),
                          Expanded(
                            flex: 12,
                            child: Column(
                              children: <Widget>[
                                Expanded(child: writerPanel),
                                _PanelDivider(vertical: false),
                                Expanded(child: detailPanel),
                              ],
                            ),
                          ),
                        ],
                      )
                    : _CompactWorkbench(
                        controller: compactTabController,
                        breakpointPanel: breakpointPanel,
                        writerPanel: writerPanel,
                        detailPanel: detailPanel,
                      );

        return Padding(
          padding: EdgeInsets.all(isShortHeight ? 8.r : 12.r),
          child: Column(
            children: <Widget>[
              MemoryToolResultSelectionBar(
                actions: <MemoryToolResultSelectionActionData>[
                  MemoryToolResultSelectionActionData(
                    icon: Icons.refresh_rounded,
                    onTap: breakpointActionState.isLoading ? null : refreshAll,
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.play_arrow_rounded,
                    onTap: breakpointActionState.isLoading || !isPaused
                        ? null
                        : () async {
                            await ref
                                .read(memoryBreakpointActionProvider.notifier)
                                .resumeAfterBreakpoint(pid: pid);
                          },
                  ),
                  MemoryToolResultSelectionActionData(
                    icon: Icons.layers_clear_rounded,
                    onTap: breakpointActionState.isLoading
                        ? null
                        : () async {
                            await ref
                                .read(memoryBreakpointActionProvider.notifier)
                                .clearMemoryBreakpointHits(pid: pid);
                          },
                  ),
                ],
              ),
              SizedBox(height: outerSpacing),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.colorScheme.surface.withValues(alpha: 0.84),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(workbenchPadding),
                    child: body,
                  ),
                ),
              ),
              if (!useLandscapeWorkbench) ...<Widget>[
                SizedBox(height: isShortHeight ? 4.r : 6.r),
                _DebugStatsBar(
                  state: state,
                  selectedBreakpoint: selectedBreakpoint,
                  hitCount: hits.length,
                  breakpointCount: breakpoints.length,
                  writerCount: writerGroups.length,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _CompactWorkbench extends StatelessWidget {
  const _CompactWorkbench({
    required this.controller,
    required this.breakpointPanel,
    required this.writerPanel,
    required this.detailPanel,
  });

  final TabController controller;
  final Widget breakpointPanel;
  final Widget writerPanel;
  final Widget detailPanel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TabBar(
          controller: controller,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(10.r),
            color: context.colorScheme.primary.withValues(alpha: 0.12),
          ),
          labelColor: context.colorScheme.primary,
          unselectedLabelColor: context.colorScheme.onSurfaceVariant,
          labelStyle: context.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          tabs: <Widget>[
            Tab(text: context.isZh ? '断点' : 'Breakpoints'),
            Tab(text: context.isZh ? '写入源' : 'Writers'),
            Tab(text: context.isZh ? '详情' : 'Detail'),
          ],
        ),
        SizedBox(height: 10.r),
        Expanded(
          child: TabBarView(
            controller: controller,
            children: <Widget>[
              breakpointPanel,
              writerPanel,
              detailPanel,
            ],
          ),
        ),
      ],
    );
  }
}

class _LandscapeDetailWorkbench extends StatelessWidget {
  const _LandscapeDetailWorkbench({
    required this.controller,
    required this.writerPanel,
    required this.detailPanel,
  });

  final TabController controller;
  final Widget writerPanel;
  final Widget detailPanel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: TabBar(
            controller: controller,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(10.r),
              color: context.colorScheme.primary.withValues(alpha: 0.12),
            ),
            labelColor: context.colorScheme.primary,
            unselectedLabelColor: context.colorScheme.onSurfaceVariant,
            labelStyle: context.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            tabs: <Widget>[
              Tab(text: context.isZh ? '写入源' : 'Writers'),
              Tab(text: context.isZh ? '详情' : 'Detail'),
            ],
          ),
        ),
        SizedBox(height: 8.r),
        Expanded(
          child: TabBarView(
            controller: controller,
            children: <Widget>[
              writerPanel,
              detailPanel,
            ],
          ),
        ),
      ],
    );
  }
}

class _DebugSection extends StatelessWidget {
  const _DebugSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 8.r),
        Expanded(child: child),
      ],
    );
  }
}

class _BreakpointList extends StatelessWidget {
  const _BreakpointList({
    required this.breakpointsAsync,
    required this.selectedBreakpointId,
    required this.onSelect,
    required this.onToggleEnabled,
    required this.onRemove,
  });

  final AsyncValue<List<MemoryBreakpoint>> breakpointsAsync;
  final String? selectedBreakpointId;
  final ValueChanged<String> onSelect;
  final Future<void> Function(MemoryBreakpoint breakpoint) onToggleEnabled;
  final Future<void> Function(MemoryBreakpoint breakpoint) onRemove;

  @override
  Widget build(BuildContext context) {
    return breakpointsAsync.when(
      data: (breakpoints) {
        if (breakpoints.isEmpty) {
          return _DebugEmptyState(
            message: context.isZh ? '还没有断点' : 'No breakpoints yet',
          );
        }
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: breakpoints.length,
          separatorBuilder: (_, _) => SizedBox(height: 6.r),
          itemBuilder: (context, index) {
            final breakpoint = breakpoints[index];
            final isSelected = breakpoint.id == selectedBreakpointId;
            return _ListItemShell(
              selected: isSelected,
              onTap: () {
                onSelect(breakpoint.id);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '0x${breakpoint.address.toRadixString(16).toUpperCase()}',
                          style: context.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _InlineChip(
                        text: breakpoint.enabled
                            ? (context.isZh ? '已启用' : 'Enabled')
                            : (context.isZh ? '已禁用' : 'Disabled'),
                        active: breakpoint.enabled,
                      ),
                    ],
                  ),
                  SizedBox(height: 6.r),
                  Wrap(
                    spacing: 6.r,
                    runSpacing: 6.r,
                    children: <Widget>[
                      _InlineChip(
                        text: _mapAccessType(context, breakpoint.accessType),
                      ),
                      _InlineChip(text: '${breakpoint.length}B'),
                      _InlineChip(
                        text: breakpoint.pauseProcessOnHit
                            ? (context.isZh ? '命中即暂停' : 'Pause On Hit')
                            : (context.isZh ? '仅记录' : 'Record Only'),
                      ),
                      _InlineChip(
                        text: '${breakpoint.hitCount}${context.isZh ? ' 次命中' : ' hits'}',
                      ),
                    ],
                  ),
                  if (breakpoint.lastHitAtMillis != null) ...<Widget>[
                    SizedBox(height: 6.r),
                    Text(
                      context.isZh
                          ? '最近命中 ${_formatTimestamp(breakpoint.lastHitAtMillis!)}'
                          : 'Last hit ${_formatTimestamp(breakpoint.lastHitAtMillis!)}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (breakpoint.lastError.isNotEmpty) ...<Widget>[
                    SizedBox(height: 6.r),
                    Text(
                      breakpoint.lastError,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.error,
                      ),
                    ),
                  ],
                  SizedBox(height: 6.r),
                  Row(
                    children: <Widget>[
                      Switch.adaptive(
                        value: breakpoint.enabled,
                        onChanged: (_) async {
                          await onToggleEnabled(breakpoint);
                        },
                      ),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          await onRemove(breakpoint);
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
      error: (error, _) => _DebugEmptyState(message: error.toString()),
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
    );
  }

  String _mapAccessType(BuildContext context, MemoryBreakpointAccessType type) {
    return switch (type) {
      MemoryBreakpointAccessType.read => context.isZh ? '读' : 'Read',
      MemoryBreakpointAccessType.write => context.isZh ? '写' : 'Write',
      MemoryBreakpointAccessType.readWrite => context.isZh ? '读写' : 'Read/Write',
    };
  }
}

class _WriterGroupList extends StatelessWidget {
  const _WriterGroupList({
    required this.groups,
    required this.selectedWriterKey,
    required this.onSelectWriter,
  });

  final List<_WriterGroup> groups;
  final String? selectedWriterKey;
  final ValueChanged<_WriterGroup> onSelectWriter;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return _DebugEmptyState(
        message: context.isZh ? '这个断点还没有命中' : 'No writer groups for the selected breakpoint',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: groups.length,
      separatorBuilder: (_, _) => SizedBox(height: 6.r),
      itemBuilder: (context, index) {
        final group = groups[index];
        final isSelected = group.key == selectedWriterKey;
        return _ListItemShell(
          selected: isSelected,
          onTap: () {
            onSelectWriter(group);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _formatTimestamp(group.latestTimestamp),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _InlineChip(
                    text: '${group.threadCount} ${context.isZh ? '线程' : 'thr'}',
                  ),
                ],
              ),
              SizedBox(height: 4.r),
              Text(
                'PC 0x${group.pc.toRadixString(16).toUpperCase()}',
                style: context.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (group.instructionText.isNotEmpty) ...<Widget>[
                SizedBox(height: 3.r),
                Text(
                  _formatInstruction(group.instructionText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              SizedBox(height: 3.r),
              Text(
                '${group.moduleName.isEmpty ? '[anonymous]' : group.moduleName}+0x${group.moduleOffset.toRadixString(16).toUpperCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 6.r),
              Wrap(
                spacing: 6.r,
                runSpacing: 6.r,
                children: <Widget>[
                  _InlineChip(
                    text: '${group.hitCount}${context.isZh ? ' 次命中' : ' hits'}',
                    active: true,
                  ),
                  if (group.topTransition != null)
                    _InlineChip(text: group.topTransition!.summary),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WriterDetail extends StatelessWidget {
  const _WriterDetail({required this.group, required this.breakpoint});

  final _WriterGroup? group;
  final MemoryBreakpoint? breakpoint;

  @override
  Widget build(BuildContext context) {
    if (group == null) {
      return _DebugEmptyState(
        message: context.isZh ? '选择一个写入源查看详情' : 'Select a writer group to inspect details',
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 6.r,
            runSpacing: 6.r,
            children: <Widget>[
              _InlineChip(
                text: 'PC 0x${group!.pc.toRadixString(16).toUpperCase()}',
              ),
              _InlineChip(
                text: '${group!.threadCount} ${context.isZh ? '线程' : 'threads'}',
              ),
              _InlineChip(
                text: '${group!.hitCount} ${context.isZh ? '次命中' : 'hits'}',
              ),
              _InlineChip(text: _formatTimestamp(group!.latestTimestamp)),
            ],
          ),
          SizedBox(height: 10.r),
          _DetailBlock(
            title: context.isZh ? '模块偏移' : 'Module Offset',
            value:
                '${group!.moduleName.isEmpty ? '[anonymous]' : group!.moduleName}+0x${group!.moduleOffset.toRadixString(16).toUpperCase()}',
            monospace: true,
          ),
          if (group!.instructionText.isNotEmpty) ...<Widget>[
            SizedBox(height: 8.r),
            _DetailBlock(
              title: context.isZh ? '指令' : 'Instruction',
              value: group!.instructionText.trim(),
              monospace: true,
            ),
          ],
          if (group!.topTransition != null) ...<Widget>[
            SizedBox(height: 8.r),
            _DetailBlock(
              title: context.isZh ? '常见改写' : 'Top Transition',
              value:
                  '${group!.topTransition!.summary}\n${context.isZh ? '出现' : 'count'} ${group!.topTransition!.count}',
              active: true,
              monospace: true,
            ),
          ],
          if (breakpoint != null) ...<Widget>[
            SizedBox(height: 8.r),
            _DetailBlock(
              title: context.isZh ? '断点地址' : 'Breakpoint Address',
              value: '0x${breakpoint!.address.toRadixString(16).toUpperCase()}',
              monospace: true,
            ),
            SizedBox(height: 8.r),
            _DetailBlock(
              title: context.isZh ? '监控模式' : 'Watch Mode',
              value:
                  '${_mapAccessType(context, breakpoint!.accessType)} · ${breakpoint!.pauseProcessOnHit ? (context.isZh ? '命中即暂停' : 'Pause On Hit') : (context.isZh ? '仅记录' : 'Record Only')}',
            ),
          ],
          SizedBox(height: 10.r),
          Text(
            context.isZh ? '最近命中' : 'Recent Hits',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.r),
          ...group!.hits.take(5).map(
            (hit) => Padding(
              padding: EdgeInsets.only(bottom: 6.r),
              child: _StaticHitEntry(hit: hit),
            ),
          ),
        ],
      ),
    );
  }

  String _mapAccessType(BuildContext context, MemoryBreakpointAccessType type) {
    return switch (type) {
      MemoryBreakpointAccessType.read => context.isZh ? '读' : 'Read',
      MemoryBreakpointAccessType.write => context.isZh ? '写' : 'Write',
      MemoryBreakpointAccessType.readWrite => context.isZh ? '读写' : 'Read/Write',
    };
  }
}

class _StaticHitEntry extends StatelessWidget {
  const _StaticHitEntry({required this.hit});

  final MemoryBreakpointHit hit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(10.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _formatTimestamp(hit.timestampMillis),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _InlineChip(text: 'TID ${hit.threadId}'),
              ],
            ),
            SizedBox(height: 4.r),
            Text(
              _formatTransition(hit.oldValue, hit.newValue),
              style: context.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelDivider extends StatelessWidget {
  const _PanelDivider({required this.vertical});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    if (vertical) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.r),
        child: VerticalDivider(
          width: 1,
          thickness: 1,
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.r),
      child: Divider(
        height: 1,
        thickness: 1,
        color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
      ),
    );
  }
}

class _DebugStatsBar extends StatelessWidget {
  const _DebugStatsBar({
    required this.state,
    required this.selectedBreakpoint,
    required this.hitCount,
    required this.breakpointCount,
    required this.writerCount,
  });

  final MemoryBreakpointState? state;
  final MemoryBreakpoint? selectedBreakpoint;
  final int hitCount;
  final int breakpointCount;
  final int writerCount;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            MemoryToolResultStatChip(
              label: context.isZh ? '断点' : 'Breakpoints',
              value: breakpointCount,
            ),
            SizedBox(width: 6.r),
            MemoryToolResultStatChip(
              label: context.isZh ? '活动' : 'Active',
              value: state?.activeBreakpointCount ?? 0,
            ),
            SizedBox(width: 6.r),
            MemoryToolResultStatChip(
              label: context.isZh ? '写点' : 'Writers',
              value: writerCount,
            ),
            SizedBox(width: 6.r),
            MemoryToolResultStatChip(
              label: context.isZh ? '当前命中' : 'Hits',
              value: hitCount,
            ),
            SizedBox(width: 6.r),
            MemoryToolResultStatChip(
              label: context.isZh ? '待处理' : 'Pending',
              value: state?.pendingHitCount ?? 0,
            ),
            if (selectedBreakpoint != null) ...<Widget>[
              SizedBox(width: 6.r),
              MemoryToolResultStatChip(
                label: context.isZh ? '长度' : 'Length',
                value: selectedBreakpoint!.length,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ListItemShell extends StatelessWidget {
  const _ListItemShell({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? context.colorScheme.primary.withValues(alpha: 0.07)
                : context.colorScheme.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: selected
                  ? context.colorScheme.primary.withValues(alpha: 0.42)
                  : context.colorScheme.outlineVariant.withValues(alpha: 0.32),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(10.r),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _InlineChip extends StatelessWidget {
  const _InlineChip({required this.text, this.active = false});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? context.colorScheme.primary.withValues(alpha: 0.08)
            : context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.r, vertical: 4.r),
        child: Text(
          text,
          style: context.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: active ? context.colorScheme.primary : null,
          ),
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.title,
    required this.value,
    this.active = false,
    this.monospace = false,
  });

  final String title;
  final String value;
  final bool active;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active
            ? context.colorScheme.primary.withValues(alpha: 0.08)
            : context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: active
              ? context.colorScheme.primary.withValues(alpha: 0.18)
              : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(10.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: context.textTheme.labelMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 4.r),
            Text(
              value,
              style: context.textTheme.bodyMedium?.copyWith(
                fontFamily: monospace ? 'monospace' : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugEmptyState extends StatelessWidget {
  const _DebugEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.r),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurface.withValues(alpha: 0.66),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DebugProcessEmptyState extends StatelessWidget {
  const _DebugProcessEmptyState();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colorScheme.surface.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(18.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.bug_report_rounded,
                size: 28.r,
                color: context.colorScheme.primary,
              ),
              SizedBox(height: 10.r),
              Text(
                context.isZh ? '请先选择进程' : 'Select a process first',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6.r),
              Text(
                context.isZh
                    ? '长按搜索结果、预览结果或暂存结果创建断点后，这里会显示命中记录和写入指令。'
                    : 'Create a watchpoint from a long-press result to inspect hit records here.',
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

MemoryBreakpoint? _resolveSelectedBreakpoint({
  required List<MemoryBreakpoint> breakpoints,
  required String? selectedBreakpointId,
}) {
  for (final breakpoint in breakpoints) {
    if (breakpoint.id == selectedBreakpointId) {
      return breakpoint;
    }
  }
  if (breakpoints.isEmpty) {
    return null;
  }
  return breakpoints.first;
}

_WriterGroup? _resolveSelectedWriterGroup({
  required List<_WriterGroup> groups,
  required String? selectedWriterKey,
}) {
  for (final group in groups) {
    if (group.key == selectedWriterKey) {
      return group;
    }
  }
  if (groups.isEmpty) {
    return null;
  }
  return groups.first;
}

List<_WriterGroup> _buildWriterGroups(List<MemoryBreakpointHit> hits) {
  final grouped = <String, List<MemoryBreakpointHit>>{};
  for (final hit in hits) {
    grouped.putIfAbsent(_buildWriterKey(hit), () => <MemoryBreakpointHit>[]).add(hit);
  }
  final groups = grouped.entries.map((entry) {
    final sortedHits = entry.value.toList(growable: false)
      ..sort((left, right) => right.timestampMillis.compareTo(left.timestampMillis));
    final transitions = _buildTransitions(sortedHits);
    return _WriterGroup(
      key: entry.key,
      pc: sortedHits.first.pc,
      moduleName: sortedHits.first.moduleName,
      moduleOffset: sortedHits.first.moduleOffset,
      instructionText: sortedHits.first.instructionText,
      hitCount: sortedHits.length,
      threadCount: sortedHits.map((hit) => hit.threadId).toSet().length,
      latestTimestamp: sortedHits.first.timestampMillis,
      hits: sortedHits,
      topTransition: transitions.isEmpty ? null : transitions.first,
    );
  }).toList(growable: false)
    ..sort((left, right) {
      final countCompare = right.hitCount.compareTo(left.hitCount);
      if (countCompare != 0) {
        return countCompare;
      }
      return right.latestTimestamp.compareTo(left.latestTimestamp);
    });
  return groups;
}

List<_WriterTransition> _buildTransitions(List<MemoryBreakpointHit> hits) {
  final grouped = <String, List<MemoryBreakpointHit>>{};
  for (final hit in hits) {
    grouped.putIfAbsent(_formatTransition(hit.oldValue, hit.newValue), () => <MemoryBreakpointHit>[]).add(hit);
  }
  final transitions = grouped.entries.map((entry) {
    final sortedHits = entry.value.toList(growable: false)
      ..sort((left, right) => right.timestampMillis.compareTo(left.timestampMillis));
    return _WriterTransition(
      summary: entry.key,
      count: sortedHits.length,
      latestTimestamp: sortedHits.first.timestampMillis,
    );
  }).toList(growable: false)
    ..sort((left, right) {
      final countCompare = right.count.compareTo(left.count);
      if (countCompare != 0) {
        return countCompare;
      }
      return right.latestTimestamp.compareTo(left.latestTimestamp);
    });
  return transitions;
}

String _buildWriterKey(MemoryBreakpointHit hit) {
  return '${hit.pc}_${hit.moduleName}_${hit.moduleOffset}_${hit.instructionText}';
}

String _formatInstruction(String instruction) {
  return instruction.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String _formatTransition(Uint8List oldValue, Uint8List newValue) {
  return '${_formatBytes(oldValue)} -> ${_formatBytes(newValue)}';
}

String _formatBytes(Uint8List bytes) {
  if (bytes.isEmpty) {
    return '--';
  }
  return bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}

String _formatTimestamp(int millis) {
  final time = DateTime.fromMillisecondsSinceEpoch(millis);
  final year = time.year.toString().padLeft(4, '0');
  final month = time.month.toString().padLeft(2, '0');
  final day = time.day.toString().padLeft(2, '0');
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  final second = time.second.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute:$second';
}

class _WriterGroup {
  const _WriterGroup({
    required this.key,
    required this.pc,
    required this.moduleName,
    required this.moduleOffset,
    required this.instructionText,
    required this.hitCount,
    required this.threadCount,
    required this.latestTimestamp,
    required this.hits,
    required this.topTransition,
  });

  final String key;
  final int pc;
  final String moduleName;
  final int moduleOffset;
  final String instructionText;
  final int hitCount;
  final int threadCount;
  final int latestTimestamp;
  final List<MemoryBreakpointHit> hits;
  final _WriterTransition? topTransition;
}

class _WriterTransition {
  const _WriterTransition({
    required this.summary,
    required this.count,
    required this.latestTimestamp,
  });

  final String summary;
  final int count;
  final int latestTimestamp;
}
