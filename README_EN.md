# JsxposedX

- Default README: [`README.md`](README.md)
- Chinese documentation: [`README_CN.md`](README_CN.md)
- Release：[`Download`](https://jsxposed.org)
  
JsxposedX is a Flutter Android application for Xposed/LSPosed and Frida workflows. It combines a
  Flutter UI layer with Android-side Xposed hooks, LSPosed service integration, native bridge
  modules, shared IDE run configurations, and PowerShell-based install/debug scripts.

## Project Overview

- App name: `JsxposedX`
- Locales: English and Simplified Chinese
- Main tabs: `Home`, `Project`, `Repository`, `Settings`
- Home status cards: `AI`, `Root`, `Xposed`, `Frida`, `Zygisk module`
- Project entries: `Quick Functions`, `AI Reverse`, `Xposed Project`, `Frida Project`

## Main Features

- Xposed project pages, code editor, and visual editor
- Frida project pages, script management, target switch, hook bundle, and editor
- AI Reverse page with AI chat, APK context, and SO analysis tools
- Quick Functions for common hook-related switches
- Crypto audit log and JS editor
- SO analysis pages with `ELF Info`, `Exports`, `Imports`, `JNI`, `Strings`, and `Sections`
- Built-in manuals in `assets/raws/JsxposedX_API.md`, `assets/raws/JsxposedX_API_en.md`,
  `assets/raws/Frida_API.md`, and `assets/raws/Frida_API_en.md`
- `Repository` tab is currently a placeholder page

## Quick Functions

Current quick-function keys in code:

- `injectTip`
- `removeScreenshotDetection`
- `removeDialogs`
- `removeCaptureDetection`
- `modifiedVersion`
- `hideXposed`
- `hideRoot`
- `hideApps`
- `algorithmicTracking`

## Why the Build and Debug Flow Differs from a Normal Flutter App

This repository is not only a Flutter UI project.

- `android/app/src/main/AndroidManifest.xml` declares Xposed module metadata
- `android/app/src/main/assets/xposed_init` points to `com.jsxposed.x.MainHook`
- `android/app/src/main/resources/META-INF/xposed/module.prop` sets `minApiVersion=53`,
  `targetApiVersion=100`, and `staticScope=false`
- `android/app/src/main/kotlin/com/jsxposed/x/App.kt` initializes the LSPosed service
- `android/app/src/main/kotlin/com/jsxposed/x/NativeProvider.kt` registers native bridge modules for
  `Pinia`, `StatusManagement`, `App`, `Project`, `ApkAnalysis`, `SoAnalysis`, `LSPosed`, and
  `ZygiskFrida`

Because of that, installation and verification involve the Android/Xposed side as well as the
Flutter side.

## Requirements

- Flutter SDK
- Android SDK and `adb`
- Windows PowerShell for the shared scripts in this repository
- A rooted test environment for Xposed/LSPosed flows
- A Zygisk/Frida environment for Frida flows

## Key Directories

- `lib/`: Flutter UI, routes, providers, and feature pages
- `lib/pigeons/`: Pigeon bridge definitions
- `lib/generated/`: generated Dart bridge code
- `android/app/src/main/kotlin/com/jsxposed/x/`: Android app code, Xposed hooks, and native bridge
  implementations
- `android/app/src/main/assets/xposed_init`: Xposed entry list
- `android/app/src/main/resources/META-INF/xposed/module.prop`: Xposed module properties
- `.buildScript/`: shared PowerShell scripts for code generation and debug install
- `.idea/runConfigurations/`: shared IDE run configurations

## Shared IDE Run Configurations

This repository commits `.idea/runConfigurations/`.

After cloning, JetBrains IDEs can load these shared run configurations:

- `watch_pigeons` -> runs `.buildScript/pigen_watch.ps1`
- `build_for_xposed_type` -> runs `.buildScript/run_install_debug.ps1 -SkipAttach`

## Pigeon Code Generation

`.buildScript/pigen_watch.ps1` watches `lib/pigeons/**/*.dart` and:

- generates Dart bridge files into `lib/generated`
- generates Kotlin bridge files under `android/app/src/main/kotlin/...`
- creates `*NativeImpl.kt` template files when they are missing

Run it from the repository root:

```powershell
.\.buildScript\pigen_watch.ps1
```

## Debug Install Script

`.buildScript/run_install_debug.ps1` is the debug install script in this repository.

It:

- runs `:app:installDebug`
- syncs `versionName` and `versionCode` from `pubspec.yaml` into `android/local.properties`
- resolves the target device from `-DeviceId`, `ANDROID_SERIAL`, the Android Studio selected device,
  or a single connected `adb` device
- waits after install for package replacement broadcasts and LSPosed rescan
- can force-stop the app, launch it, and run `flutter attach`

Run it from the repository root:

```powershell
.\.buildScript\run_install_debug.ps1
```

Useful switches:

```powershell
.\.buildScript\run_install_debug.ps1 -SkipAttach
.\.buildScript\run_install_debug.ps1 -SkipLaunch
.\.buildScript\run_install_debug.ps1 -DeviceId <serial>
```

This script is used for the Xposed/LSPosed debug install flow. It is not a replacement for normal
Flutter hot reload.

## Standard Build

Standard Flutter build commands are still available:

```powershell
flutter build apk --debug
flutter build apk --release
```

`.buildScript/run_install_debug.ps1` handles the install, launch, and attach flow for device-side
verification.

## Release Signing

Release signing is loaded from local `android/key.properties`.

- `android/key.properties` is not committed
- the keystore file is not committed
- keep signing data in local files only

## Typical Development Flow

```powershell
flutter pub get
.\.buildScript\pigen_watch.ps1
.\.buildScript\run_install_debug.ps1
flutter attach
```

After installation, continue verification on the device in the LSPosed/Xposed or Zygisk/Frida
environment.

## Notes

- The shared scripts in this repository are PowerShell scripts.
- If you do not use Windows, follow the same steps manually.
- `flutter run` is still available for normal Flutter iteration, while this repository also keeps an
  Android/Xposed install flow for module verification.
