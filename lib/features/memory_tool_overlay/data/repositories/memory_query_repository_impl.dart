import 'package:JsxposedX/features/memory_tool_overlay/data/datasources/memory_query_datasource.dart';
import 'package:JsxposedX/features/memory_tool_overlay/domain/repositories/memory_query_repository.dart';

class MemoryQueryRepositoryImpl implements MemoryQueryRepository {
  final MemoryQueryDatasource dataSource;

  MemoryQueryRepositoryImpl({required this.dataSource});

  @override
  Future<int> getPid({required String packageName}) async {
    return await dataSource.getPid(packageName: packageName);
  }
}
