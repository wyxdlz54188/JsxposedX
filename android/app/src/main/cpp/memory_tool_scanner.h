#ifndef JSXPOSEDX_MEMORY_TOOL_SCANNER_H
#define JSXPOSEDX_MEMORY_TOOL_SCANNER_H

#include <vector>

#include "memory_tool_reader.h"
#include "memory_tool_session.h"

namespace memory_tool {

std::vector<SearchResultEntry> FirstScan(ProcessMemoryReader* reader,
                                         const std::vector<MemoryRegion>& regions,
                                         const std::vector<uint8_t>& pattern,
                                         SearchValueType type);

std::vector<SearchResultEntry> NextScan(ProcessMemoryReader* reader,
                                        const std::vector<SearchResultEntry>& previous_results,
                                        const std::vector<uint8_t>& pattern);

}  // namespace memory_tool

#endif  // JSXPOSEDX_MEMORY_TOOL_SCANNER_H
