#ifndef JSXPOSEDX_MEMORY_TOOL_INSTRUCTION_H
#define JSXPOSEDX_MEMORY_TOOL_INSTRUCTION_H

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

#include "memory_tool_session.h"

namespace memory_tool {

struct MemoryInstructionInfo {
    bool is_valid = false;
    std::string architecture;
    size_t size = 0;
    std::vector<uint8_t> raw_bytes;
    std::string text;
};

MemoryInstructionInfo ReadMemoryInstruction(int pid, uint64_t address);

InstructionPatchResultView PatchMemoryInstructionAtAddress(int pid,
                                                           uint64_t address,
                                                           const std::string& input_text);

}  // namespace memory_tool

#endif  // JSXPOSEDX_MEMORY_TOOL_INSTRUCTION_H
