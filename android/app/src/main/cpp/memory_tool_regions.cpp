#include "memory_tool_regions.h"

#include <fstream>
#include <sstream>
#include <stdexcept>
#include <string>

namespace memory_tool {

namespace {

bool HasReadPermission(const std::string& perms) {
    return !perms.empty() && perms[0] == 'r';
}

bool IsAnonymousPath(const std::string& path) {
    return path.empty() || path[0] == '[';
}

}  // namespace

std::vector<MemoryRegion> ReadProcessRegions(int pid,
                                             bool readable_only,
                                             bool include_anonymous,
                                             bool include_file_backed) {
    std::ifstream stream("/proc/" + std::to_string(pid) + "/maps");
    if (!stream.is_open()) {
        throw std::runtime_error("Unable to open process maps.");
    }

    std::vector<MemoryRegion> regions;
    std::string line;
    while (std::getline(stream, line)) {
        if (line.empty()) {
            continue;
        }

        std::istringstream parser(line);
        std::string address_range;
        std::string perms;
        std::string offset;
        std::string dev;
        std::string inode;
        if (!(parser >> address_range >> perms >> offset >> dev >> inode)) {
            continue;
        }

        std::string path;
        std::getline(parser, path);
        if (!path.empty() && path.front() == ' ') {
            path.erase(0, path.find_first_not_of(' '));
        }

        const auto separator = address_range.find('-');
        if (separator == std::string::npos) {
            continue;
        }

        const uint64_t start = std::stoull(address_range.substr(0, separator), nullptr, 16);
        const uint64_t end = std::stoull(address_range.substr(separator + 1), nullptr, 16);
        if (end <= start) {
            continue;
        }

        const bool is_anonymous = IsAnonymousPath(path);
        if (readable_only && !HasReadPermission(perms)) {
            continue;
        }
        if (!include_anonymous && is_anonymous) {
            continue;
        }
        if (!include_file_backed && !is_anonymous) {
            continue;
        }

        MemoryRegion region;
        region.start_address = start;
        region.end_address = end;
        region.perms = perms;
        region.size = end - start;
        region.path = path;
        region.is_anonymous = is_anonymous;
        regions.push_back(region);
    }

    return regions;
}

}  // namespace memory_tool
