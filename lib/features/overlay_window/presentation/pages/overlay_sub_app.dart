import 'package:JsxposedX/common/widgets/app_bootstrap.dart';
import 'package:JsxposedX/features/overlay_window/presentation/pages/overlay_window_host_page.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class OverlaySubApp extends ConsumerWidget {
  const OverlaySubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBootstrap(
      builder: (context, locale, lightTheme, darkTheme, themeMode) {
        return MaterialApp(
          title: 'JsxposedX Overlay',
          locale: locale,
          localizationsDelegates: AppBootstrap.localizationsDelegates,
          supportedLocales: AppBootstrap.supportedLocales,
          localeResolutionCallback: (deviceLocale, supportedLocales) => locale,
          debugShowCheckedModeBanner: false,
          theme: _buildOverlayTheme(lightTheme),
          darkTheme: _buildOverlayTheme(darkTheme),
          themeMode: themeMode,
          home: const OverlayWindowHostPage(),
        );
      },
    );
  }

  ThemeData _buildOverlayTheme(ThemeData theme) {
    return theme.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      cardColor: Colors.transparent,
      dialogTheme: const DialogThemeData(backgroundColor: Colors.transparent),
    );
  }
}
