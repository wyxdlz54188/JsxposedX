import 'package:JsxposedX/core/enums/ai_api_type.dart';
import 'package:JsxposedX/core/models/ai_config.dart';

const String builtinAiConfigId = 'builtin_closeai_default';
const String builtinAiConfigName = '帕帝接口';
const String builtinAiConfigBaseUrl = 'https://padi.closeai.hk/v1';

AiConfig buildBuiltinAiConfig() {
  return const AiConfig(
    id: builtinAiConfigId,
    name: builtinAiConfigName,
    apiKey: '',
    apiUrl: builtinAiConfigBaseUrl,
    moduleName: 'gpt-5.4',
    maxToken: 4096,
    temperature: 1.0,
    memoryRounds: 6,
    apiType: AiApiType.openaiResponses,
  );
}

bool isBuiltinAiConfigId(String id) => id == builtinAiConfigId;
bool isBuiltinAiConfig(AiConfig config) => isBuiltinAiConfigId(config.id);
