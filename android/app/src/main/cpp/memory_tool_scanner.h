#ifndef JSXPOSEDX_MEMORY_TOOL_SCANNER_H
#define JSXPOSEDX_MEMORY_TOOL_SCANNER_H

#include <cstddef>
#include <cstdint>
#include <functional>
#include <vector>

#include "memory_tool_reader.h"
#include "memory_tool_session.h"

namespace memory_tool {

struct SearchScanProgress {
    size_t processed_region_count = 0;
    size_t total_region_count = 0;
    size_t processed_entry_count = 0;
    size_t total_entry_count = 0;
    uint64_t processed_byte_count = 0;
    uint64_t total_byte_count = 0;
    size_t result_count = 0;
};

using SearchProgressCallback = std::function<bool(const SearchScanProgress&)>;

struct SearchPatternVariant {
    SearchValueType type = SearchValueType::kI32;
    std::vector<uint8_t> pattern;
};

std::vector<SearchResultEntry> FirstScan(ProcessMemoryReader* reader,
                                         const std::vector<MemoryRegion>& regions,
                                         const std::vector<uint8_t>& pattern,
                                         SearchValueType type,
                                         const SearchProgressCallback& progress_callback);

std::vector<SearchResultEntry> FirstScanMultiType(
    ProcessMemoryReader* reader,
    const std::vector<MemoryRegion>& regions,
    const std::vector<SearchPatternVariant>& variants,
    const SearchProgressCallback& progress_callback);

std::vector<SearchResultEntry> FirstScanXor(ProcessMemoryReader* reader,
                                            const std::vector<MemoryRegion>& regions,
                                            uint32_t target_value,
                                            bool little_endian,
                                            const SearchProgressCallback& progress_callback);

std::vector<SearchResultEntry> NextScan(ProcessMemoryReader* reader,
                                        const std::vector<SearchResultEntry>& previous_results,
                                        const std::vector<uint8_t>& pattern,
                                        const SearchProgressCallback& progress_callback);

std::vector<SearchResultEntry> NextScanMultiType(
    ProcessMemoryReader* reader,
    const std::vector<SearchResultEntry>& previous_results,
    const std::vector<SearchPatternVariant>& variants,
    const SearchProgressCallback& progress_callback);

std::vector<SearchResultEntry> NextScanXor(ProcessMemoryReader* reader,
                                           const std::vector<SearchResultEntry>& previous_results,
                                           uint32_t target_value,
                                           bool little_endian,
                                           const SearchProgressCallback& progress_callback);

}  // namespace memory_tool

#endif  // JSXPOSEDX_MEMORY_TOOL_SCANNER_H
