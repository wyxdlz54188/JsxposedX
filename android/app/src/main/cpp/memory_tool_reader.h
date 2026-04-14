#ifndef JSXPOSEDX_MEMORY_TOOL_READER_H
#define JSXPOSEDX_MEMORY_TOOL_READER_H

#include <cstddef>
#include <cstdint>
#include <vector>

namespace memory_tool {

class ProcessMemoryReader {
public:
    explicit ProcessMemoryReader(int pid);
    ~ProcessMemoryReader();

    ProcessMemoryReader(const ProcessMemoryReader&) = delete;
    ProcessMemoryReader& operator=(const ProcessMemoryReader&) = delete;

    bool Read(uint64_t address, size_t size, std::vector<uint8_t>* buffer) const;

private:
    bool ReadWithProcessVmReadv(uint64_t address, size_t size, std::vector<uint8_t>* buffer) const;
    bool ReadWithPread(uint64_t address, size_t size, std::vector<uint8_t>* buffer) const;

    int pid_ = 0;
    int mem_fd_ = -1;
};

bool IsProcessAlive(int pid);

}  // namespace memory_tool

#endif  // JSXPOSEDX_MEMORY_TOOL_READER_H
