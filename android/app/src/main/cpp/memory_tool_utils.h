#ifndef JSXPOSEDX_MEMORY_TOOL_UTILS_H
#define JSXPOSEDX_MEMORY_TOOL_UTILS_H

#include <jni.h>

#include <string>

namespace memory_tool::utils {

std::string Trim(const std::string& value);

std::string EscapeShellSingleQuotes(const std::string& value);

std::string BuildGetPidCommand(const std::string& package_name);

std::string WrapCommandWithSu(const std::string& command);

bool ExecuteCommand(const std::string& command, std::string* output, int* exit_code);

jlong ParsePid(const std::string& output);

}  // namespace memory_tool::utils

#endif  // JSXPOSEDX_MEMORY_TOOL_UTILS_H
