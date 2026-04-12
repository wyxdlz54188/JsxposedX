import 'package:JsxposedX/generated/memory_tool.g.dart';

class MemoryQueryDatasource {
  final _native = MemoryToolNative();

  Future<int> getPid({required String packageName}) async {
    return await _native.getPid(packageName: packageName);
  }
}
