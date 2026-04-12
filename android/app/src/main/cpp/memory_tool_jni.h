#ifndef JSXPOSEDX_MEMORY_TOOL_JNI_H
#define JSXPOSEDX_MEMORY_TOOL_JNI_H

#include <jni.h>

namespace memory_tool {

class MemoryToolJniBridge {
public:
    static jlong GetPid(JNIEnv* env, jstring package_name);
};

}  // namespace memory_tool

#endif  // JSXPOSEDX_MEMORY_TOOL_JNI_H
