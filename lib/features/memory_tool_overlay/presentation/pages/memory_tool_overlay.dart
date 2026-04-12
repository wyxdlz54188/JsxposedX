import 'package:JsxposedX/common/widgets/cache_image.dart';
import 'package:JsxposedX/common/widgets/loading.dart';
import 'package:JsxposedX/common/widgets/overlay_window/overlay_window.dart';
import 'package:JsxposedX/common/widgets/ref_error.dart';
import 'package:JsxposedX/core/constants/assets_constants.dart';
import 'package:JsxposedX/core/extensions/context_extensions.dart';
import 'package:JsxposedX/features/memory_tool_overlay/presentation/providers/memory_query_provider.dart';
import 'package:JsxposedX/features/overlay_window/domain/models/overlay_window_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MemoryToolOverlay extends HookConsumerWidget {
  const MemoryToolOverlay({super.key});

  OverlayWindowConfig get overlayConfig => OverlayWindowConfig(
    sceneId: 0,
    bubbleSize: OverlayWindowPresentation.defaultBubbleSize,
    notificationTitle: (context) => context.l10n.overlayMemoryToolTitle,
    notificationContent: (context) =>
        context.l10n.overlayWindowNotificationContent,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useAutomaticKeepAlive();
    const packageName = 'x.muxue.pro';
    final pidAsync = ref.watch(getPidProvider(packageName: packageName));
    return OverlayWindowScaffold(
      overlayConfig: overlayConfig,
      borderRadius: BorderRadius.circular(8.r),
      overlayBar: OverlayWindowBar(
        backgroundColor: context.colorScheme.surface.withValues(alpha: 0.3),
        title: Text(
          context.l10n.overlayMemoryToolTitle,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8.r),
          child: CacheImage(imageUrl: AssetsConstants.logo, size: 40.sp),
        ),
        showMinimizeAction: true,
        showCloseAction: false,
      ),
      backgroundColor: context.colorScheme.surface.withValues(alpha: 0.6),
      margin: EdgeInsets.all(8.r),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              children: <Widget>[
                pidAsync.when(
                  data: (pid) {
                    return Text("pid:$pid");
                  },
                  error: (error, stack) => RefError(
                    onRetry: () {
                      ref.invalidate(getPidProvider(packageName: packageName));
                    },
                  ),
                  loading: () => const Loading(),
                ),
                // ListTile(
                //   title: const Text('data'),
                //   onTap: () {
                //
                //     pidAsync.when(
                //       data: (pid) {
                //         ToastOverlayMessage.show("msg");
                //         ToastOverlayMessage.show("pid:$pid");
                //       },
                //       error: (error, stack) => RefError(onRetry: () {}),
                //       loading: () => const Loading(),
                //     );
                //   },
                // ),
              ],
            ),
          ),
        ],
      ),
      bottomBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
