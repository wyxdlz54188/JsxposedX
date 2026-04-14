#include "memory_tool_engine.h"

#include <algorithm>
#include <stdexcept>

#include "memory_tool_reader.h"
#include "memory_tool_regions.h"
#include "memory_tool_scanner.h"
#include "memory_tool_value.h"

namespace memory_tool {

MemoryToolEngine& MemoryToolEngine::Instance() {
    static MemoryToolEngine instance;
    return instance;
}

std::vector<MemoryRegion> MemoryToolEngine::GetMemoryRegions(int pid,
                                                             int offset,
                                                             int limit,
                                                             bool readable_only,
                                                             bool include_anonymous,
                                                             bool include_file_backed) {
    const std::vector<MemoryRegion> all_regions =
        ReadProcessRegions(pid, readable_only, include_anonymous, include_file_backed);
    if (limit <= 0 || offset >= static_cast<int>(all_regions.size())) {
        return {};
    }

    const size_t start = static_cast<size_t>(std::max(offset, 0));
    const size_t end = std::min(all_regions.size(), start + static_cast<size_t>(limit));
    return std::vector<MemoryRegion>(all_regions.begin() + static_cast<std::ptrdiff_t>(start),
                                     all_regions.begin() + static_cast<std::ptrdiff_t>(end));
}

SearchSessionStateView MemoryToolEngine::GetSearchSessionState() {
    std::lock_guard<std::mutex> lock(mutex_);
    return BuildSessionStateLocked();
}

std::vector<SearchResultView> MemoryToolEngine::GetSearchResults(int offset, int limit) {
    std::lock_guard<std::mutex> lock(mutex_);
    EnsureActiveSessionLocked();
    if (limit <= 0 || offset >= static_cast<int>(session_.results.size())) {
        return {};
    }

    const size_t start = static_cast<size_t>(std::max(offset, 0));
    const size_t end = std::min(session_.results.size(), start + static_cast<size_t>(limit));
    std::vector<SearchResultView> views;
    views.reserve(end - start);
    for (size_t index = start; index < end; ++index) {
        views.push_back(BuildSearchResultViewLocked(session_.results[index]));
    }
    return views;
}

std::vector<MemoryValuePreview> MemoryToolEngine::ReadMemoryValues(
    const std::vector<MemoryReadRequest>& requests) {
    std::lock_guard<std::mutex> lock(mutex_);
    EnsureActiveSessionLocked();
    if (!IsProcessAlive(session_.pid)) {
        session_.Clear();
        throw std::runtime_error("Search session target process is no longer available.");
    }

    ProcessMemoryReader reader(session_.pid);
    std::vector<MemoryValuePreview> previews;
    previews.reserve(requests.size());
    for (const MemoryReadRequest& request : requests) {
        const size_t length = ResolveValueByteLength(request.type, request.length);
        if (length == 0) {
            continue;
        }

        std::vector<uint8_t> buffer;
        if (!reader.Read(request.address, length, &buffer)) {
            continue;
        }

        MemoryValuePreview preview;
        preview.address = request.address;
        preview.type = request.type;
        preview.raw_bytes = buffer;
        preview.display_value =
            FormatDisplayValue(request.type, buffer, session_.little_endian);
        previews.push_back(std::move(preview));
    }
    return previews;
}

void MemoryToolEngine::FirstScan(int pid,
                                 const SearchValue& value,
                                 SearchMatchMode match_mode,
                                 bool /*scan_all_readable_regions*/) {
    if (match_mode != SearchMatchMode::kExact) {
        throw std::runtime_error("Only exact scan is supported.");
    }

    std::vector<uint8_t> pattern;
    std::string error;
    if (!BuildSearchPattern(value, &pattern, &error)) {
        throw std::runtime_error(error.empty() ? "Invalid search value." : error);
    }

    const std::vector<MemoryRegion> regions = ReadProcessRegions(pid, true, true, true);
    ProcessMemoryReader reader(pid);
    const std::vector<SearchResultEntry> results =
        ::memory_tool::FirstScan(&reader, regions, pattern, value.type);

    std::lock_guard<std::mutex> lock(mutex_);
    session_.Clear();
    session_.has_active_session = true;
    session_.pid = pid;
    session_.type = value.type;
    session_.exact_mode = true;
    session_.little_endian = value.little_endian;
    session_.value_size = pattern.size();
    session_.regions = regions;
    session_.results = results;
}

void MemoryToolEngine::NextScan(const SearchValue& value, SearchMatchMode match_mode) {
    if (match_mode != SearchMatchMode::kExact) {
        throw std::runtime_error("Only exact scan is supported.");
    }

    std::lock_guard<std::mutex> lock(mutex_);
    EnsureActiveSessionLocked();
    if (!IsProcessAlive(session_.pid)) {
        session_.Clear();
        throw std::runtime_error("Search session target process is no longer available.");
    }

    std::vector<uint8_t> pattern;
    std::string error;
    if (!BuildSearchPattern(value, &pattern, &error)) {
        throw std::runtime_error(error.empty() ? "Invalid search value." : error);
    }
    if (value.type != session_.type) {
        throw std::runtime_error("Search value type does not match the active session.");
    }

    ProcessMemoryReader reader(session_.pid);
    session_.results = ::memory_tool::NextScan(&reader, session_.results, pattern);
    session_.value_size = pattern.size();
    session_.little_endian = value.little_endian;
}

void MemoryToolEngine::ResetSearchSession() {
    std::lock_guard<std::mutex> lock(mutex_);
    session_.Clear();
}

SearchSessionStateView MemoryToolEngine::BuildSessionStateLocked() const {
    SearchSessionStateView state;
    state.has_active_session = session_.has_active_session;
    state.pid = session_.pid;
    state.type = session_.type;
    state.region_count = session_.regions.size();
    state.result_count = session_.results.size();
    state.exact_mode = session_.exact_mode;
    return state;
}

SearchResultView MemoryToolEngine::BuildSearchResultViewLocked(const SearchResultEntry& entry) const {
    SearchResultView view;
    view.address = entry.address;
    view.region_start = entry.region_start;
    view.type = session_.type;
    view.raw_bytes = entry.raw_bytes;
    view.display_value =
        FormatDisplayValue(session_.type, entry.raw_bytes, session_.little_endian);
    return view;
}

void MemoryToolEngine::EnsureActiveSessionLocked() const {
    if (!session_.has_active_session) {
        throw std::runtime_error("No active search session.");
    }
}

}  // namespace memory_tool
