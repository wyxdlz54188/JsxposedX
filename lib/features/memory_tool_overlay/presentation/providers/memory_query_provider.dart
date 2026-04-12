import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:JsxposedX/features/memory_tool_overlay/data/datasources/memory_query_datasource.dart';
import 'package:JsxposedX/features/memory_tool_overlay/data/repositories/memory_query_repository_impl.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_query_repository.dart';

part 'memory_query_provider.g.dart';

@riverpod
MemoryQueryRepository memoryQueryRepository(Ref ref) {
  final dataSource = MemoryQueryDatasource();
  return MemoryQueryRepositoryImpl(dataSource: dataSource);
}

@riverpod
Future<int> getPid(Ref ref, {required String packageName}) async {
  return await ref
      .watch(memoryQueryRepositoryProvider)
      .getPid(packageName: packageName);
}
