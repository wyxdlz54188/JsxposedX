import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// 仓库 Tab
class RepositoryTab extends HookConsumerWidget {
  const RepositoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Text(
            context.isChinese ? "正在努力开发中..." : "Efforts are being made...",
          ),
        ),
      ],
    );
  }
}
