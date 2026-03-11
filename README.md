# JsxposedX

- English: [`README_EN.md`](README_EN.md)
- 中文：[`README_CN.md`](README_CN.md)
- Release：[`Download`](https://jsxposed.org)
JsxposedX is a Flutter Android application for Xposed/LSPosed and Frida workflows.

## Summary

- Flutter UI with Android-side Xposed hooks, LSPosed service integration, and native bridge modules
- Project entries for `Quick Functions`, `AI Reverse`, `Xposed Project`, and `Frida Project`
- Additional pages for crypto audit and SO analysis
- Pigeon code generation via `.buildScript/pigen_watch.ps1`
- Debug install flow via `.buildScript/run_install_debug.ps1`
- Shared run configurations in `.idea/runConfigurations/`: `watch_pigeons` and `build_for_xposed_type`

## Build Note

This repository is not a normal Flutter-only app. Device-side verification also involves the Android/Xposed side, so the repository includes shared PowerShell scripts and shared IDE run configurations.