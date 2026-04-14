#ifndef JSXPOSEDX_MEMORY_TOOL_ENGINE_H
#define JSXPOSEDX_MEMORY_TOOL_ENGINE_H

#include <mutex>
#include <vector>

#include "memory_tool_session.h"

namespace memory_tool {

class MemoryToolEngine {
public:
    static MemoryToolEngine& Instance();

    std::vector<MemoryRegion> GetMemoryRegions(int pid,
                                               int offset,
                                               int limit,
                                               bool readable_only,
                                               bool include_anonymous,
                                               bool include_file_backed);

    SearchSessionStateView GetSearchSessionState();

    std::vector<SearchResultView> GetSearchResults(int offset, int limit);

    std::vector<MemoryValuePreview> ReadMemoryValues(const std::vector<MemoryReadRequest>& requests);

    void FirstScan(int pid,
                   const SearchValue& value,
                   SearchMatchMode match_mode,
                   bool scan_all_readable_regions);

    void NextScan(const SearchValue& value, SearchMatchMode match_mode);

    void ResetSearchSession();

private:
    MemoryToolEngine() = default;

    SearchSessionStateView BuildSessionStateLocked() const;

    SearchResultView BuildSearchResultViewLocked(const SearchResultEntry& entry) const;

    void EnsureActiveSessionLocked() const;

    SearchSession session_;
    mutable std::mutex mutex_;
};

}  // namespace memory_tool

#endif  // JSXPOSEDX_MEMORY_TOOL_ENGINE_H
