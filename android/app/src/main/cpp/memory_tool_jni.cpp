#include <string>

#include "memory_tool_jni.h"
#include "memory_tool_utils.h"

namespace memory_tool {

jlong MemoryToolJniBridge::GetPid(JNIEnv* env, jstring package_name) {
    if (package_name == nullptr) {
        return 0;
    }

    const char* package_name_chars = env->GetStringUTFChars(package_name, nullptr);
    if (package_name_chars == nullptr) {
        return 0;
    }

    const std::string inner_command = utils::BuildGetPidCommand(package_name_chars);
    env->ReleaseStringUTFChars(package_name, package_name_chars);
    const std::string command = utils::WrapCommandWithSu(inner_command);

    std::string output;
    int exit_code = 0;

    if (!utils::ExecuteCommand(command, &output, &exit_code)) {
        return 0;
    }

    if (exit_code != 0 && exit_code != 256) {
        return 0;
    }

    return utils::ParsePid(output);
}

}  // namespace memory_tool

extern "C" JNIEXPORT jlong JNICALL
Java_com_jsxposed_x_core_bridge_memory_1tool_1native_MemoryToolJni_getPid(
        JNIEnv* env,
        jobject /* thiz */,
        jstring package_name) {
    return memory_tool::MemoryToolJniBridge::GetPid(env, package_name);
}
