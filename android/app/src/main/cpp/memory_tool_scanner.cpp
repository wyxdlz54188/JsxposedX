#include "memory_tool_scanner.h"

#include <algorithm>
#include <atomic>
#include <cstring>
#include <functional>
#include <mutex>
#include <thread>
#include <unordered_map>
#include <unordered_set>

namespace memory_tool {

namespace {

constexpr size_t kChunkSize = 64 * 1024 * 1024;
constexpr size_t kNextScanBatchSize = 16 * 1024;
constexpr size_t kProgressEntryInterval = 128 * 1024;
constexpr size_t kProgressRegionInterval = 32;
constexpr uint64_t kProgressByteInterval = 256ULL * 1024ULL * 1024ULL;

struct IndexRange {
    size_t start = 0;
    size_t end = 0;
};

size_t ResolveStep(SearchValueType type) {
    switch (type) {
        case SearchValueType::kI8:
        case SearchValueType::kBytes:
            return 1;
        case SearchValueType::kI16:
            return 2;
        case SearchValueType::kI32:
        case SearchValueType::kF32:
            return 4;
        case SearchValueType::kI64:
        case SearchValueType::kF64:
            return 8;
    }
    return 1;
}

size_t ResolveNextScanWorkerCount(size_t entry_count) {
    if (entry_count <= kNextScanBatchSize) {
        return 1;
    }

    const unsigned int hardware_workers = std::thread::hardware_concurrency();
    const size_t preferred_workers = hardware_workers == 0 ? 4U : hardware_workers;
    const size_t target_entries_per_worker = kNextScanBatchSize * 4;
    const size_t required_workers =
        std::max<size_t>(1, (entry_count + target_entries_per_worker - 1) / target_entries_per_worker);
    return std::max<size_t>(1, std::min(preferred_workers, required_workers));
}

std::vector<IndexRange> PartitionIndexRanges(size_t item_count, size_t worker_count) {
    if (item_count == 0 || worker_count == 0) {
        return {};
    }

    worker_count = std::min(item_count, worker_count);
    std::vector<IndexRange> ranges;
    ranges.reserve(worker_count);
    const size_t base_size = item_count / worker_count;
    const size_t remainder = item_count % worker_count;

    size_t start = 0;
    for (size_t index = 0; index < worker_count; ++index) {
        const size_t length = base_size + (index < remainder ? 1 : 0);
        ranges.push_back(IndexRange{start, start + length});
        start += length;
    }
    return ranges;
}

template <typename T>
T ReadScalar(const uint8_t* address) {
    T value{};
    std::memcpy(&value, address, sizeof(T));
    return value;
}

void AppendResult(uint64_t address,
                  uint64_t region_start,
                  SearchValueType matched_type,
                  std::vector<SearchResultEntry>* results) {
    if (results == nullptr) {
        return;
    }
    SearchResultEntry entry;
    entry.address = address;
    entry.region_start = region_start;
    entry.matched_type = matched_type;
    results->push_back(std::move(entry));
}

uint32_t ByteSwap32(uint32_t value) {
    return ((value & 0x000000FFU) << 24U) |
           ((value & 0x0000FF00U) << 8U) |
           ((value & 0x00FF0000U) >> 8U) |
           ((value & 0xFF000000U) >> 24U);
}

bool HostIsLittleEndian() {
    uint16_t value = 0x1;
    return *reinterpret_cast<uint8_t*>(&value) == 0x1;
}

uint32_t DecodeU32(const uint8_t* current, bool little_endian) {
    uint32_t value = ReadScalar<uint32_t>(current);
    if (HostIsLittleEndian() != little_endian) {
        value = ByteSwap32(value);
    }
    return value;
}

void SortResultsByAddress(std::vector<SearchResultEntry>* results) {
    if (results == nullptr) {
        return;
    }

    std::sort(results->begin(),
              results->end(),
              [](const SearchResultEntry& left, const SearchResultEntry& right) {
                  if (left.address != right.address) {
                      return left.address < right.address;
                  }
                  return static_cast<int>(left.matched_type) <
                         static_cast<int>(right.matched_type);
              });
}

void DeduplicateResultsByAddress(std::vector<SearchResultEntry>* results) {
    if (results == nullptr || results->empty()) {
        return;
    }

    std::unordered_set<uint64_t> seen_addresses;
    std::vector<SearchResultEntry> unique_results;
    unique_results.reserve(results->size());
    for (SearchResultEntry& entry : *results) {
        if (!seen_addresses.insert(entry.address).second) {
            continue;
        }
        unique_results.push_back(std::move(entry));
    }
    *results = std::move(unique_results);
}

bool IsPatternMatch(const uint8_t* current, const std::vector<uint8_t>& pattern) {
    if (current == nullptr || pattern.empty()) {
        return false;
    }

    switch (pattern.size()) {
        case 1:
            return current[0] == pattern[0];
        case 2:
            return ReadScalar<uint16_t>(current) == ReadScalar<uint16_t>(pattern.data());
        case 4:
            return ReadScalar<uint32_t>(current) == ReadScalar<uint32_t>(pattern.data());
        case 8:
            return ReadScalar<uint64_t>(current) == ReadScalar<uint64_t>(pattern.data());
        default:
            return std::memcmp(current, pattern.data(), pattern.size()) == 0;
    }
}

void ScanChunkForSingleByte(const uint8_t* buffer,
                            uint8_t needle,
                            uint64_t base_address,
                            uint64_t region_start,
                            size_t scan_limit,
                            SearchValueType matched_type,
                            std::vector<SearchResultEntry>* results) {
    const uint8_t* cursor = buffer;
    const uint8_t* end = buffer + static_cast<std::ptrdiff_t>(scan_limit);
    while (cursor < end) {
        const void* match = std::memchr(cursor, needle, static_cast<size_t>(end - cursor));
        if (match == nullptr) {
            break;
        }
        const auto* match_ptr = static_cast<const uint8_t*>(match);
        AppendResult(base_address + static_cast<uint64_t>(match_ptr - buffer),
                     region_start,
                     matched_type,
                     results);
        cursor = match_ptr + 1;
    }
}

template <typename T>
void ScanChunkForScalar(const uint8_t* buffer,
                        const std::vector<uint8_t>& pattern,
                        uint64_t base_address,
                        uint64_t region_start,
                        size_t scan_limit,
                        size_t step,
                        SearchValueType matched_type,
                        std::vector<SearchResultEntry>* results) {
    const T expected = ReadScalar<T>(pattern.data());
    for (size_t index = 0; index < scan_limit; index += step) {
        if (ReadScalar<T>(buffer + static_cast<std::ptrdiff_t>(index)) != expected) {
            continue;
        }
        AppendResult(base_address + index, region_start, matched_type, results);
    }
}

void ScanChunkForBytePattern(const uint8_t* buffer,
                             size_t buffer_size,
                             const std::vector<uint8_t>& pattern,
                             uint64_t base_address,
                             uint64_t region_start,
                             size_t scan_limit,
                             SearchValueType matched_type,
                             std::vector<SearchResultEntry>* results) {
    if (pattern.size() == 1) {
        ScanChunkForSingleByte(buffer,
                               pattern.front(),
                               base_address,
                               region_start,
                               scan_limit,
                               matched_type,
                               results);
        return;
    }

    const auto search_begin = buffer;
    auto search_cursor = search_begin;
    const auto search_end = buffer + static_cast<std::ptrdiff_t>(buffer_size);
    const auto searcher = std::boyer_moore_horspool_searcher(pattern.begin(), pattern.end());

    while (search_cursor < search_end) {
        const auto match = std::search(search_cursor, search_end, searcher);
        if (match == search_end) {
            break;
        }
        const size_t match_index =
            static_cast<size_t>(match - search_begin);
        if (match_index >= scan_limit) {
            break;
        }

        AppendResult(base_address + static_cast<uint64_t>(match_index),
                     region_start,
                     matched_type,
                     results);
        search_cursor = match + 1;
    }
}

void ScanChunkForGenericPattern(const uint8_t* buffer,
                                const std::vector<uint8_t>& pattern,
                                uint64_t base_address,
                                uint64_t region_start,
                                size_t scan_limit,
                                size_t step,
                                SearchValueType matched_type,
                                std::vector<SearchResultEntry>* results) {
    for (size_t index = 0; index < scan_limit; index += step) {
        if (std::memcmp(buffer + static_cast<std::ptrdiff_t>(index),
                        pattern.data(),
                        pattern.size()) != 0) {
            continue;
        }
        AppendResult(base_address + index, region_start, matched_type, results);
    }
}

void ScanChunkForPattern(const uint8_t* buffer,
                         size_t buffer_size,
                         const std::vector<uint8_t>& pattern,
                         SearchValueType type,
                         uint64_t base_address,
                         uint64_t region_start,
                         size_t scan_limit,
                         size_t step,
                         SearchValueType matched_type,
                         std::vector<SearchResultEntry>* results) {
    if (buffer == nullptr || results == nullptr || pattern.empty() || scan_limit == 0) {
        return;
    }

    if (step == 1) {
        ScanChunkForBytePattern(
            buffer,
            buffer_size,
            pattern,
            base_address,
            region_start,
            scan_limit,
            matched_type,
            results);
        return;
    }

    if (pattern.size() == step) {
        switch (type) {
            case SearchValueType::kI16:
                ScanChunkForScalar<uint16_t>(
                    buffer,
                    pattern,
                    base_address,
                    region_start,
                    scan_limit,
                    step,
                    matched_type,
                    results);
                return;
            case SearchValueType::kI32:
            case SearchValueType::kF32:
                ScanChunkForScalar<uint32_t>(
                    buffer,
                    pattern,
                    base_address,
                    region_start,
                    scan_limit,
                    step,
                    matched_type,
                    results);
                return;
            case SearchValueType::kI64:
            case SearchValueType::kF64:
                ScanChunkForScalar<uint64_t>(
                    buffer,
                    pattern,
                    base_address,
                    region_start,
                    scan_limit,
                    step,
                    matched_type,
                    results);
                return;
            case SearchValueType::kI8:
            case SearchValueType::kBytes:
                break;
        }
    }

    ScanChunkForGenericPattern(
        buffer,
        pattern,
        base_address,
        region_start,
        scan_limit,
        step,
        matched_type,
        results);
}

void ScanChunkForXorPattern(const uint8_t* buffer,
                            size_t buffer_size,
                            uint32_t target_value,
                            bool little_endian,
                            uint64_t base_address,
                            uint64_t region_start,
                            size_t scan_limit,
                            std::vector<SearchResultEntry>* results) {
    if (buffer == nullptr || results == nullptr || buffer_size < sizeof(uint32_t) || scan_limit == 0) {
        return;
    }

    const size_t max_limit = std::min(scan_limit, buffer_size - sizeof(uint32_t) + 1);
    for (size_t index = 0; index < max_limit; index += sizeof(uint32_t)) {
        const uint64_t address = base_address + index;
        const uint32_t stored_value = DecodeU32(buffer + static_cast<std::ptrdiff_t>(index),
                                                little_endian);
        const uint32_t address_low = static_cast<uint32_t>(address & 0xFFFFFFFFULL);
        if ((stored_value ^ address_low) != target_value) {
            continue;
        }
        AppendResult(address, region_start, SearchValueType::kI32, results);
    }
}

std::vector<SearchResultEntry> FinalizeMultiTypeFirstScan(std::vector<SearchResultEntry> results) {
    DeduplicateResultsByAddress(&results);
    SortResultsByAddress(&results);
    return results;
}

}  // namespace

std::vector<SearchResultEntry> FirstScan(ProcessMemoryReader* reader,
                                         const std::vector<MemoryRegion>& regions,
                                         const std::vector<uint8_t>& pattern,
                                         SearchValueType type,
                                         const SearchProgressCallback& progress_callback) {
    std::vector<SearchResultEntry> results;
    if (reader == nullptr || pattern.empty()) {
        return results;
    }

    const size_t step = ResolveStep(type);
    const size_t overlap = pattern.size() > 1 ? pattern.size() - 1 : 0;
    SearchScanProgress progress;
    uint64_t last_reported_byte_count = 0;
    progress.total_region_count = regions.size();
    for (const MemoryRegion& region : regions) {
        progress.total_byte_count += region.size;
    }
    if (progress_callback && !progress_callback(progress)) {
        return results;
    }

    std::vector<uint8_t> buffer;
    buffer.reserve(kChunkSize + overlap);

    for (const MemoryRegion& region : regions) {
        for (uint64_t cursor = region.start_address; cursor < region.end_address;) {
            const size_t remaining = static_cast<size_t>(region.end_address - cursor);
            const size_t base_read_size = std::min(kChunkSize, remaining);
            const size_t read_size = std::min(remaining, base_read_size + overlap);

            buffer.resize(read_size);
            if (!reader->ReadInto(cursor, read_size, buffer.data()) ||
                buffer.size() < pattern.size()) {
                cursor += base_read_size;
                continue;
            }

            const size_t scan_limit = std::min(base_read_size, buffer.size() - pattern.size() + 1);
            ScanChunkForPattern(buffer.data(),
                                buffer.size(),
                                pattern,
                                type,
                                cursor,
                                region.start_address,
                                scan_limit,
                                step,
                                type,
                                &results);

            progress.processed_byte_count += base_read_size;
            progress.result_count = results.size();
            const bool should_report =
                (progress.processed_byte_count - last_reported_byte_count) >= kProgressByteInterval;
            if (should_report && progress_callback && !progress_callback(progress)) {
                return results;
            }
            if (should_report) {
                last_reported_byte_count = progress.processed_byte_count;
            }
            cursor += base_read_size;
        }

        ++progress.processed_region_count;
        progress.result_count = results.size();
        const bool should_report_region =
            (progress.processed_region_count % kProgressRegionInterval) == 0 ||
            progress.processed_region_count == progress.total_region_count;
        if (should_report_region && progress_callback && !progress_callback(progress)) {
            return results;
        }
    }

    return results;
}

std::vector<SearchResultEntry> FirstScanMultiType(
    ProcessMemoryReader* reader,
    const std::vector<MemoryRegion>& regions,
    const std::vector<SearchPatternVariant>& variants,
    const SearchProgressCallback& progress_callback) {
    std::vector<SearchResultEntry> results;
    if (reader == nullptr || variants.empty()) {
        return results;
    }

    size_t max_pattern_size = 0;
    for (const SearchPatternVariant& variant : variants) {
        if (variant.pattern.empty()) {
            continue;
        }
        max_pattern_size = std::max(max_pattern_size, variant.pattern.size());
    }
    if (max_pattern_size == 0) {
        return results;
    }

    const size_t overlap = max_pattern_size > 1 ? max_pattern_size - 1 : 0;
    SearchScanProgress progress;
    uint64_t last_reported_byte_count = 0;
    progress.total_region_count = regions.size();
    for (const MemoryRegion& region : regions) {
        progress.total_byte_count += region.size;
    }
    if (progress_callback && !progress_callback(progress)) {
        return results;
    }

    std::vector<uint8_t> buffer;
    buffer.reserve(kChunkSize + overlap);

    for (const MemoryRegion& region : regions) {
        for (uint64_t cursor = region.start_address; cursor < region.end_address;) {
            const size_t remaining = static_cast<size_t>(region.end_address - cursor);
            const size_t base_read_size = std::min(kChunkSize, remaining);
            const size_t read_size = std::min(remaining, base_read_size + overlap);

            buffer.resize(read_size);
            if (!reader->ReadInto(cursor, read_size, buffer.data()) || buffer.empty()) {
                cursor += base_read_size;
                continue;
            }

            for (const SearchPatternVariant& variant : variants) {
                if (variant.pattern.empty() || buffer.size() < variant.pattern.size()) {
                    continue;
                }

                const size_t scan_limit =
                    std::min(base_read_size, buffer.size() - variant.pattern.size() + 1);
                ScanChunkForPattern(buffer.data(),
                                    buffer.size(),
                                    variant.pattern,
                                    variant.type,
                                    cursor,
                                    region.start_address,
                                    scan_limit,
                                    ResolveStep(variant.type),
                                    variant.type,
                                    &results);
            }

            progress.processed_byte_count += base_read_size;
            progress.result_count = results.size();
            const bool should_report =
                (progress.processed_byte_count - last_reported_byte_count) >= kProgressByteInterval;
            if (should_report && progress_callback && !progress_callback(progress)) {
                return FinalizeMultiTypeFirstScan(std::move(results));
            }
            if (should_report) {
                last_reported_byte_count = progress.processed_byte_count;
            }
            cursor += base_read_size;
        }

        ++progress.processed_region_count;
        progress.result_count = results.size();
        const bool should_report_region =
            (progress.processed_region_count % kProgressRegionInterval) == 0 ||
            progress.processed_region_count == progress.total_region_count;
        if (should_report_region && progress_callback && !progress_callback(progress)) {
            return FinalizeMultiTypeFirstScan(std::move(results));
        }
    }

    return FinalizeMultiTypeFirstScan(std::move(results));
}

std::vector<SearchResultEntry> FirstScanXor(ProcessMemoryReader* reader,
                                            const std::vector<MemoryRegion>& regions,
                                            uint32_t target_value,
                                            bool little_endian,
                                            const SearchProgressCallback& progress_callback) {
    std::vector<SearchResultEntry> results;
    if (reader == nullptr) {
        return results;
    }

    constexpr size_t kPatternSize = sizeof(uint32_t);
    const size_t overlap = kPatternSize - 1;
    SearchScanProgress progress;
    uint64_t last_reported_byte_count = 0;
    progress.total_region_count = regions.size();
    for (const MemoryRegion& region : regions) {
        progress.total_byte_count += region.size;
    }
    if (progress_callback && !progress_callback(progress)) {
        return results;
    }

    std::vector<uint8_t> buffer;
    buffer.reserve(kChunkSize + overlap);

    for (const MemoryRegion& region : regions) {
        for (uint64_t cursor = region.start_address; cursor < region.end_address;) {
            const size_t remaining = static_cast<size_t>(region.end_address - cursor);
            const size_t base_read_size = std::min(kChunkSize, remaining);
            const size_t read_size = std::min(remaining, base_read_size + overlap);

            buffer.resize(read_size);
            if (!reader->ReadInto(cursor, read_size, buffer.data()) ||
                buffer.size() < kPatternSize) {
                cursor += base_read_size;
                continue;
            }

            const size_t scan_limit = std::min(base_read_size, buffer.size() - kPatternSize + 1);
            ScanChunkForXorPattern(buffer.data(),
                                   buffer.size(),
                                   target_value,
                                   little_endian,
                                   cursor,
                                   region.start_address,
                                   scan_limit,
                                   &results);

            progress.processed_byte_count += base_read_size;
            progress.result_count = results.size();
            const bool should_report =
                (progress.processed_byte_count - last_reported_byte_count) >= kProgressByteInterval;
            if (should_report && progress_callback && !progress_callback(progress)) {
                return results;
            }
            if (should_report) {
                last_reported_byte_count = progress.processed_byte_count;
            }
            cursor += base_read_size;
        }

        ++progress.processed_region_count;
        progress.result_count = results.size();
        const bool should_report_region =
            (progress.processed_region_count % kProgressRegionInterval) == 0 ||
            progress.processed_region_count == progress.total_region_count;
        if (should_report_region && progress_callback && !progress_callback(progress)) {
            return results;
        }
    }

    return results;
}

std::vector<SearchResultEntry> NextScan(ProcessMemoryReader* reader,
                                        const std::vector<SearchResultEntry>& previous_results,
                                        const std::vector<uint8_t>& pattern,
                                        const SearchProgressCallback& progress_callback) {
    std::vector<SearchResultEntry> results;
    if (reader == nullptr || pattern.empty()) {
        return results;
    }

    SearchScanProgress progress;
    progress.total_entry_count = previous_results.size();
    progress.total_byte_count =
        static_cast<uint64_t>(previous_results.size()) * static_cast<uint64_t>(pattern.size());
    if (progress_callback && !progress_callback(progress)) {
        return results;
    }

    const size_t worker_count = ResolveNextScanWorkerCount(previous_results.size());
    const std::vector<IndexRange> ranges = PartitionIndexRanges(previous_results.size(), worker_count);
    std::vector<std::vector<SearchResultEntry>> worker_results(ranges.size());
    std::vector<std::thread> workers;
    workers.reserve(ranges.size());

    std::atomic_size_t processed_entry_count{0};
    std::atomic_uint64_t processed_byte_count{0};
    std::atomic_size_t aggregated_result_count{0};
    std::atomic_bool should_stop{false};
    std::mutex progress_mutex;

    const auto report_progress = [progress_callback,
                                  &processed_entry_count,
                                  &processed_byte_count,
                                  &aggregated_result_count,
                                  &progress_mutex,
                                  &should_stop,
                                  &progress]() {
        if (!progress_callback) {
            return true;
        }

        std::lock_guard<std::mutex> lock(progress_mutex);
        if (should_stop.load()) {
            return false;
        }

        SearchScanProgress current_progress = progress;
        current_progress.processed_entry_count = processed_entry_count.load();
        current_progress.processed_byte_count = processed_byte_count.load();
        current_progress.result_count = aggregated_result_count.load();
        if (!progress_callback(current_progress)) {
            should_stop.store(true);
            return false;
        }
        return true;
    };

    for (size_t worker_index = 0; worker_index < ranges.size(); ++worker_index) {
        const IndexRange range = ranges[worker_index];
        if (range.start >= range.end) {
            continue;
        }

        workers.emplace_back([reader,
                              &previous_results,
                              &worker_results,
                              &pattern,
                              &processed_entry_count,
                              &processed_byte_count,
                              &aggregated_result_count,
                              &should_stop,
                              &report_progress,
                              range,
                              worker_index]() {
            ProcessMemoryReader local_reader(reader->pid());
            std::vector<uint64_t> addresses;
            addresses.reserve(kNextScanBatchSize);
            FlatReadBatch batch;
            SearchScanProgress local_progress;
            std::vector<SearchResultEntry>& local_results = worker_results[worker_index];

            for (size_t start = range.start; start < range.end; start += kNextScanBatchSize) {
                if (should_stop.load()) {
                    return;
                }

                const size_t count = std::min(kNextScanBatchSize, range.end - start);
                addresses.clear();
                for (size_t index = 0; index < count; ++index) {
                    addresses.push_back(previous_results[start + index].address);
                }

                local_reader.ReadManyFlat(addresses, pattern.size(), &batch);
                for (size_t index = 0; index < count; ++index) {
                    if (!batch.HasValue(index)) {
                        continue;
                    }

                    const SearchResultEntry& candidate = previous_results[start + index];
                    if (!IsPatternMatch(batch.ValueAt(index), pattern)) {
                        continue;
                    }
                    local_results.push_back(candidate);
                }

                const size_t batch_processed_entries = count;
                const uint64_t batch_processed_bytes =
                    static_cast<uint64_t>(count) * static_cast<uint64_t>(pattern.size());
                const size_t batch_result_delta = local_results.size() - local_progress.result_count;

                processed_entry_count.fetch_add(batch_processed_entries);
                processed_byte_count.fetch_add(batch_processed_bytes);
                aggregated_result_count.fetch_add(batch_result_delta);

                local_progress.processed_entry_count += batch_processed_entries;
                local_progress.processed_byte_count += batch_processed_bytes;
                local_progress.result_count = local_results.size();

                const bool should_report =
                    (local_progress.processed_entry_count % kProgressEntryInterval) == 0 ||
                    (start + count) == range.end;
                if (should_report) {
                    if (!report_progress()) {
                        return;
                    }
                }
            }
        });
    }

    for (std::thread& worker : workers) {
        if (worker.joinable()) {
            worker.join();
        }
    }

    if (should_stop.load()) {
        return {};
    }

    size_t result_count = 0;
    for (const auto& entries : worker_results) {
        result_count += entries.size();
    }
    results.reserve(result_count);
    for (auto& entries : worker_results) {
        results.insert(results.end(),
                       std::make_move_iterator(entries.begin()),
                       std::make_move_iterator(entries.end()));
    }

    if (progress_callback) {
        SearchScanProgress completed_progress = progress;
        completed_progress.processed_entry_count = previous_results.size();
        completed_progress.processed_byte_count = progress.total_byte_count;
        completed_progress.result_count = results.size();
        progress_callback(completed_progress);
    }
    return results;
}

std::vector<SearchResultEntry> NextScanMultiType(
    ProcessMemoryReader* reader,
    const std::vector<SearchResultEntry>& previous_results,
    const std::vector<SearchPatternVariant>& variants,
    const SearchProgressCallback& progress_callback) {
    std::vector<SearchResultEntry> results;
    if (reader == nullptr || variants.empty()) {
        return results;
    }

    std::unordered_map<int, std::vector<uint8_t>> pattern_by_type;
    size_t max_pattern_size = 0;
    for (const SearchPatternVariant& variant : variants) {
        if (variant.pattern.empty()) {
            continue;
        }
        pattern_by_type[static_cast<int>(variant.type)] = variant.pattern;
        max_pattern_size = std::max(max_pattern_size, variant.pattern.size());
    }
    if (pattern_by_type.empty() || max_pattern_size == 0) {
        return results;
    }

    SearchScanProgress progress;
    progress.total_entry_count = previous_results.size();
    progress.total_byte_count =
        static_cast<uint64_t>(previous_results.size()) * static_cast<uint64_t>(max_pattern_size);
    if (progress_callback && !progress_callback(progress)) {
        return results;
    }

    const size_t worker_count = ResolveNextScanWorkerCount(previous_results.size());
    const std::vector<IndexRange> ranges = PartitionIndexRanges(previous_results.size(), worker_count);
    std::vector<std::vector<SearchResultEntry>> worker_results(ranges.size());
    std::vector<std::thread> workers;
    workers.reserve(ranges.size());

    std::atomic_size_t processed_entry_count{0};
    std::atomic_uint64_t processed_byte_count{0};
    std::atomic_size_t aggregated_result_count{0};
    std::atomic_bool should_stop{false};
    std::mutex progress_mutex;

    const auto report_progress = [progress_callback,
                                  &processed_entry_count,
                                  &processed_byte_count,
                                  &aggregated_result_count,
                                  &progress_mutex,
                                  &should_stop,
                                  &progress]() {
        if (!progress_callback) {
            return true;
        }

        std::lock_guard<std::mutex> lock(progress_mutex);
        if (should_stop.load()) {
            return false;
        }

        SearchScanProgress current_progress = progress;
        current_progress.processed_entry_count = processed_entry_count.load();
        current_progress.processed_byte_count = processed_byte_count.load();
        current_progress.result_count = aggregated_result_count.load();
        if (!progress_callback(current_progress)) {
            should_stop.store(true);
            return false;
        }
        return true;
    };

    for (size_t worker_index = 0; worker_index < ranges.size(); ++worker_index) {
        const IndexRange range = ranges[worker_index];
        if (range.start >= range.end) {
            continue;
        }

        workers.emplace_back([reader,
                              &previous_results,
                              &worker_results,
                              &pattern_by_type,
                              &processed_entry_count,
                              &processed_byte_count,
                              &aggregated_result_count,
                              &should_stop,
                              &report_progress,
                              range,
                              worker_index,
                              max_pattern_size]() {
            ProcessMemoryReader local_reader(reader->pid());
            std::vector<SearchResultEntry>& local_results = worker_results[worker_index];
            SearchScanProgress local_progress;

            for (size_t start = range.start; start < range.end; start += kNextScanBatchSize) {
                if (should_stop.load()) {
                    return;
                }

                const size_t count = std::min(kNextScanBatchSize, range.end - start);
                uint64_t batch_processed_bytes = 0;
                for (size_t index = 0; index < count; ++index) {
                    const SearchResultEntry& candidate = previous_results[start + index];
                    const auto pattern_iterator =
                        pattern_by_type.find(static_cast<int>(candidate.matched_type));
                    if (pattern_iterator == pattern_by_type.end()) {
                        continue;
                    }

                    const std::vector<uint8_t>& pattern = pattern_iterator->second;
                    batch_processed_bytes += static_cast<uint64_t>(pattern.size());
                    std::vector<uint8_t> buffer;
                    if (!local_reader.Read(candidate.address, pattern.size(), &buffer)) {
                        continue;
                    }
                    if (!IsPatternMatch(buffer.data(), pattern)) {
                        continue;
                    }
                    local_results.push_back(candidate);
                }

                const size_t batch_processed_entries = count;
                const size_t batch_result_delta = local_results.size() - local_progress.result_count;

                processed_entry_count.fetch_add(batch_processed_entries);
                processed_byte_count.fetch_add(batch_processed_bytes);
                aggregated_result_count.fetch_add(batch_result_delta);

                local_progress.processed_entry_count += batch_processed_entries;
                local_progress.processed_byte_count += batch_processed_bytes;
                local_progress.result_count = local_results.size();

                const bool should_report =
                    (local_progress.processed_entry_count % kProgressEntryInterval) == 0 ||
                    (start + count) == range.end;
                if (should_report && !report_progress()) {
                    return;
                }
            }
        });
    }

    for (std::thread& worker : workers) {
        if (worker.joinable()) {
            worker.join();
        }
    }

    if (should_stop.load()) {
        return {};
    }

    size_t result_count = 0;
    for (const auto& entries : worker_results) {
        result_count += entries.size();
    }
    results.reserve(result_count);
    for (auto& entries : worker_results) {
        results.insert(results.end(),
                       std::make_move_iterator(entries.begin()),
                       std::make_move_iterator(entries.end()));
    }

    if (progress_callback) {
        SearchScanProgress completed_progress = progress;
        completed_progress.processed_entry_count = previous_results.size();
        completed_progress.processed_byte_count = processed_byte_count.load();
        completed_progress.result_count = results.size();
        progress_callback(completed_progress);
    }
    return results;
}

std::vector<SearchResultEntry> NextScanXor(ProcessMemoryReader* reader,
                                           const std::vector<SearchResultEntry>& previous_results,
                                           uint32_t target_value,
                                           bool little_endian,
                                           const SearchProgressCallback& progress_callback) {
    std::vector<SearchResultEntry> results;
    if (reader == nullptr) {
        return results;
    }

    constexpr size_t kPatternSize = sizeof(uint32_t);
    SearchScanProgress progress;
    progress.total_entry_count = previous_results.size();
    progress.total_byte_count =
        static_cast<uint64_t>(previous_results.size()) * static_cast<uint64_t>(kPatternSize);
    if (progress_callback && !progress_callback(progress)) {
        return results;
    }

    const size_t worker_count = ResolveNextScanWorkerCount(previous_results.size());
    const std::vector<IndexRange> ranges = PartitionIndexRanges(previous_results.size(), worker_count);
    std::vector<std::vector<SearchResultEntry>> worker_results(ranges.size());
    std::vector<std::thread> workers;
    workers.reserve(ranges.size());

    std::atomic_size_t processed_entry_count{0};
    std::atomic_uint64_t processed_byte_count{0};
    std::atomic_size_t aggregated_result_count{0};
    std::atomic_bool should_stop{false};
    std::mutex progress_mutex;

    const auto report_progress = [progress_callback,
                                  &processed_entry_count,
                                  &processed_byte_count,
                                  &aggregated_result_count,
                                  &progress_mutex,
                                  &should_stop,
                                  &progress]() {
        if (!progress_callback) {
            return true;
        }

        std::lock_guard<std::mutex> lock(progress_mutex);
        if (should_stop.load()) {
            return false;
        }

        SearchScanProgress current_progress = progress;
        current_progress.processed_entry_count = processed_entry_count.load();
        current_progress.processed_byte_count = processed_byte_count.load();
        current_progress.result_count = aggregated_result_count.load();
        if (!progress_callback(current_progress)) {
            should_stop.store(true);
            return false;
        }
        return true;
    };

    for (size_t worker_index = 0; worker_index < ranges.size(); ++worker_index) {
        const IndexRange range = ranges[worker_index];
        if (range.start >= range.end) {
            continue;
        }

        workers.emplace_back([reader,
                              &previous_results,
                              &worker_results,
                              &processed_entry_count,
                              &processed_byte_count,
                              &aggregated_result_count,
                              &should_stop,
                              &report_progress,
                              range,
                              worker_index,
                              target_value,
                              little_endian]() {
            ProcessMemoryReader local_reader(reader->pid());
            std::vector<SearchResultEntry>& local_results = worker_results[worker_index];
            SearchScanProgress local_progress;

            for (size_t start = range.start; start < range.end; start += kNextScanBatchSize) {
                if (should_stop.load()) {
                    return;
                }

                const size_t count = std::min(kNextScanBatchSize, range.end - start);
                for (size_t index = 0; index < count; ++index) {
                    const SearchResultEntry& candidate = previous_results[start + index];
                    std::vector<uint8_t> buffer;
                    if (!local_reader.Read(candidate.address, kPatternSize, &buffer) ||
                        buffer.size() < kPatternSize) {
                        continue;
                    }

                    const uint32_t stored_value = DecodeU32(buffer.data(), little_endian);
                    const uint32_t address_low =
                        static_cast<uint32_t>(candidate.address & 0xFFFFFFFFULL);
                    if ((stored_value ^ address_low) != target_value) {
                        continue;
                    }
                    local_results.push_back(candidate);
                }

                const size_t batch_processed_entries = count;
                const uint64_t batch_processed_bytes =
                    static_cast<uint64_t>(count) * static_cast<uint64_t>(kPatternSize);
                const size_t batch_result_delta = local_results.size() - local_progress.result_count;

                processed_entry_count.fetch_add(batch_processed_entries);
                processed_byte_count.fetch_add(batch_processed_bytes);
                aggregated_result_count.fetch_add(batch_result_delta);

                local_progress.processed_entry_count += batch_processed_entries;
                local_progress.processed_byte_count += batch_processed_bytes;
                local_progress.result_count = local_results.size();

                const bool should_report =
                    (local_progress.processed_entry_count % kProgressEntryInterval) == 0 ||
                    (start + count) == range.end;
                if (should_report && !report_progress()) {
                    return;
                }
            }
        });
    }

    for (std::thread& worker : workers) {
        if (worker.joinable()) {
            worker.join();
        }
    }

    if (should_stop.load()) {
        return {};
    }

    size_t result_count = 0;
    for (const auto& entries : worker_results) {
        result_count += entries.size();
    }
    results.reserve(result_count);
    for (auto& entries : worker_results) {
        results.insert(results.end(),
                       std::make_move_iterator(entries.begin()),
                       std::make_move_iterator(entries.end()));
    }

    if (progress_callback) {
        SearchScanProgress completed_progress = progress;
        completed_progress.processed_entry_count = previous_results.size();
        completed_progress.processed_byte_count = progress.total_byte_count;
        completed_progress.result_count = results.size();
        progress_callback(completed_progress);
    }
    return results;
}

}  // namespace memory_tool
