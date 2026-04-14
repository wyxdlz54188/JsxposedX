#include "memory_tool_reader.h"

#include <cerrno>
#include <fcntl.h>
#include <signal.h>
#include <string>
#include <sys/uio.h>
#include <unistd.h>

namespace memory_tool {

ProcessMemoryReader::ProcessMemoryReader(int pid) : pid_(pid) {
    mem_fd_ = open(("/proc/" + std::to_string(pid_) + "/mem").c_str(), O_RDONLY | O_CLOEXEC);
}

ProcessMemoryReader::~ProcessMemoryReader() {
    if (mem_fd_ >= 0) {
        close(mem_fd_);
    }
}

bool ProcessMemoryReader::Read(uint64_t address,
                               size_t size,
                               std::vector<uint8_t>* buffer) const {
    if (buffer == nullptr || size == 0) {
        return false;
    }

    buffer->clear();
    buffer->resize(size);
    if (ReadWithProcessVmReadv(address, size, buffer)) {
        return true;
    }
    if (ReadWithPread(address, size, buffer)) {
        return true;
    }
    buffer->clear();
    return false;
}

bool ProcessMemoryReader::ReadWithProcessVmReadv(uint64_t address,
                                                 size_t size,
                                                 std::vector<uint8_t>* buffer) const {
    iovec local_iov{buffer->data(), size};
    iovec remote_iov{reinterpret_cast<void*>(address), size};
    const ssize_t bytes_read = process_vm_readv(pid_, &local_iov, 1, &remote_iov, 1, 0);
    return bytes_read == static_cast<ssize_t>(size);
}

bool ProcessMemoryReader::ReadWithPread(uint64_t address,
                                        size_t size,
                                        std::vector<uint8_t>* buffer) const {
    if (mem_fd_ < 0) {
        return false;
    }

    const ssize_t bytes_read = pread64(mem_fd_,
                                       buffer->data(),
                                       size,
                                       static_cast<off64_t>(address));
    return bytes_read == static_cast<ssize_t>(size);
}

bool IsProcessAlive(int pid) {
    if (pid <= 0) {
        return false;
    }

    const int result = kill(pid, 0);
    return result == 0 || errno == EPERM;
}

}  // namespace memory_tool
