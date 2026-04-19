#include "memory_tool_instruction.h"

#include <capstone/capstone.h>

#include <algorithm>
#include <cctype>
#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <dirent.h>
#include <limits>
#include <sstream>
#include <stdexcept>
#include <string>
#include <sys/ptrace.h>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

#include "memory_tool_reader.h"
#include "memory_tool_utils.h"

namespace memory_tool {

namespace {

struct InstructionDecodeConfig {
    const char* architecture = "unknown";
    size_t read_size = 0;
    cs_arch arch = CS_ARCH_ALL;
    cs_mode mode = CS_MODE_LITTLE_ENDIAN;
};

bool ResolveInstructionDecodeConfig(InstructionDecodeConfig* config) {
    if (config == nullptr) {
        return false;
    }

#if defined(__aarch64__)
    config->architecture = "aarch64";
    config->read_size = 4;
    config->arch = CS_ARCH_ARM64;
    config->mode = CS_MODE_LITTLE_ENDIAN;
    return true;
#elif defined(__arm__)
    config->architecture = "arm";
    config->read_size = 4;
    config->arch = CS_ARCH_ARM;
    config->mode = static_cast<cs_mode>(CS_MODE_ARM | CS_MODE_LITTLE_ENDIAN);
    return true;
#elif defined(__x86_64__)
    config->architecture = "x86_64";
    config->read_size = 16;
    config->arch = CS_ARCH_X86;
    config->mode = CS_MODE_64;
    return true;
#elif defined(__i386__)
    config->architecture = "x86";
    config->read_size = 16;
    config->arch = CS_ARCH_X86;
    config->mode = CS_MODE_32;
    return true;
#else
    return false;
#endif
}

std::string FormatHexFallback(const std::vector<uint8_t>& bytes) {
    const std::string encoded = utils::HexEncode(bytes);
    if (encoded.empty()) {
        return {};
    }
    return encoded;
}

std::vector<int> ReadProcessThreadIds(int pid) {
    std::vector<int> tids;
    if (pid <= 0) {
        return tids;
    }

    const std::string task_directory = "/proc/" + std::to_string(pid) + "/task";
    DIR* directory = opendir(task_directory.c_str());
    if (directory == nullptr) {
        return tids;
    }

    while (dirent* entry = readdir(directory)) {
        if (entry->d_name[0] == '.') {
            continue;
        }
        const int tid = std::atoi(entry->d_name);
        if (tid > 0) {
            tids.push_back(tid);
        }
    }

    closedir(directory);
    std::sort(tids.begin(), tids.end());
    return tids;
}

bool AttachThreadForPatch(int tid, std::string* error) {
    if (ptrace(PTRACE_ATTACH, tid, nullptr, nullptr) != 0) {
        if (error != nullptr) {
            *error = std::string("ptrace attach failed: ") + std::strerror(errno);
        }
        return false;
    }

    int status = 0;
    if (waitpid(tid, &status, __WALL) < 0) {
        if (error != nullptr) {
            *error = std::string("waitpid failed: ") + std::strerror(errno);
        }
        ptrace(PTRACE_DETACH, tid, nullptr, nullptr);
        return false;
    }

    if (!WIFSTOPPED(status)) {
        if (error != nullptr) {
            *error = "Attached thread did not stop.";
        }
        ptrace(PTRACE_DETACH, tid, nullptr, nullptr);
        return false;
    }

    return true;
}

void DetachThreadsForPatch(const std::vector<int>& tids) {
    for (auto iterator = tids.rbegin(); iterator != tids.rend(); ++iterator) {
        ptrace(PTRACE_DETACH, *iterator, nullptr, nullptr);
    }
}

bool ReadTraceWord(int tid, uint64_t address, long* value, std::string* error) {
    if (value == nullptr) {
        return false;
    }

    errno = 0;
    const long result = ptrace(
        PTRACE_PEEKTEXT,
        tid,
        reinterpret_cast<void*>(static_cast<uintptr_t>(address)),
        nullptr);
    if (result == -1L && errno != 0) {
        if (error != nullptr) {
            *error = std::string("ptrace peek failed: ") + std::strerror(errno);
        }
        return false;
    }

    *value = result;
    return true;
}

bool WriteTraceWord(int tid, uint64_t address, long value, std::string* error) {
    if (ptrace(PTRACE_POKETEXT,
               tid,
               reinterpret_cast<void*>(static_cast<uintptr_t>(address)),
               reinterpret_cast<void*>(static_cast<intptr_t>(value))) != 0) {
        if (error != nullptr) {
            *error = std::string("ptrace poke failed: ") + std::strerror(errno);
        }
        return false;
    }
    return true;
}

bool WriteInstructionBytesWithPtrace(int pid,
                                     uint64_t address,
                                     const std::vector<uint8_t>& bytes,
                                     std::string* error) {
    if (pid <= 0 || address == 0 || bytes.empty()) {
        return false;
    }

    const std::vector<int> tids = ReadProcessThreadIds(pid);
    if (tids.empty()) {
        if (error != nullptr) {
            *error = "No target threads found for instruction patch.";
        }
        return false;
    }

    std::vector<int> attached_tids;
    attached_tids.reserve(tids.size());
    for (int tid : tids) {
        if (!AttachThreadForPatch(tid, error)) {
            DetachThreadsForPatch(attached_tids);
            return false;
        }
        attached_tids.push_back(tid);
    }

    const int trace_tid = attached_tids.front();
    const uint64_t word_size = static_cast<uint64_t>(sizeof(long));
    const uint64_t aligned_start = address & ~(word_size - 1U);
    const uint64_t aligned_end =
        (address + static_cast<uint64_t>(bytes.size()) + word_size - 1U) &
        ~(word_size - 1U);

    bool success = true;
    for (uint64_t current = aligned_start; current < aligned_end; current += word_size) {
        long word = 0;
        if (!ReadTraceWord(trace_tid, current, &word, error)) {
            success = false;
            break;
        }

        auto* word_bytes = reinterpret_cast<uint8_t*>(&word);
        for (uint64_t index = 0; index < word_size; ++index) {
            const uint64_t target = current + index;
            if (target < address ||
                target >= address + static_cast<uint64_t>(bytes.size())) {
                continue;
            }
            word_bytes[index] = bytes[static_cast<size_t>(target - address)];
        }

        if (!WriteTraceWord(trace_tid, current, word, error)) {
            success = false;
            break;
        }
    }

    DetachThreadsForPatch(attached_tids);
    return success;
}

std::vector<std::string> TokenizeInstructionText(const std::string& value) {
    std::string normalized;
    normalized.reserve(value.size());
    for (char ch : value) {
        if (ch == ',' || std::isspace(static_cast<unsigned char>(ch))) {
            normalized.push_back(' ');
            continue;
        }
        normalized.push_back(static_cast<char>(std::tolower(static_cast<unsigned char>(ch))));
    }

    std::istringstream stream(normalized);
    std::vector<std::string> tokens;
    std::string token;
    while (stream >> token) {
        tokens.push_back(token);
    }
    return tokens;
}

bool ParseSignedIntegerToken(const std::string& raw_token, int64_t* value) {
    if (value == nullptr) {
        return false;
    }

    std::string token = raw_token;
    if (!token.empty() && token.front() == '#') {
        token.erase(token.begin());
    }
    if (token.empty()) {
        return false;
    }
    if (token == ".") {
        *value = 0;
        return true;
    }

    bool negative = false;
    if (token.front() == '+' || token.front() == '-') {
        negative = token.front() == '-';
        token.erase(token.begin());
    }
    if (token.empty()) {
        return false;
    }

    int base = 10;
    if (token.size() > 2 && token[0] == '0' && (token[1] == 'x' || token[1] == 'X')) {
        base = 16;
        token = token.substr(2);
    }
    if (token.empty()) {
        return false;
    }

    try {
        const uint64_t parsed = std::stoull(token, nullptr, base);
        if (negative) {
            if (parsed > static_cast<uint64_t>(std::numeric_limits<int64_t>::max()) + 1ULL) {
                return false;
            }
            *value = parsed == static_cast<uint64_t>(std::numeric_limits<int64_t>::max()) + 1ULL
                         ? std::numeric_limits<int64_t>::min()
                         : -static_cast<int64_t>(parsed);
            return true;
        }
        if (parsed > static_cast<uint64_t>(std::numeric_limits<int64_t>::max())) {
            return false;
        }
        *value = static_cast<int64_t>(parsed);
        return true;
    } catch (...) {
        return false;
    }
}

bool ParseArm64Register(const std::string& token, int* reg) {
    if (reg == nullptr) {
        return false;
    }
    if (token == "lr") {
        *reg = 30;
        return true;
    }
    if (token.size() < 2 || token.front() != 'x') {
        return false;
    }

    try {
        const int parsed = std::stoi(token.substr(1));
        if (parsed < 0 || parsed > 30) {
            return false;
        }
        *reg = parsed;
        return true;
    } catch (...) {
        return false;
    }
}

std::vector<uint8_t> EncodeArm64Word(uint32_t instruction) {
    return std::vector<uint8_t>{
        static_cast<uint8_t>(instruction & 0xFFU),
        static_cast<uint8_t>((instruction >> 8U) & 0xFFU),
        static_cast<uint8_t>((instruction >> 16U) & 0xFFU),
        static_cast<uint8_t>((instruction >> 24U) & 0xFFU),
    };
}

bool TryParseHexBytes(const std::string& input_text, std::vector<uint8_t>* bytes) {
    if (bytes == nullptr) {
        return false;
    }

    std::string trimmed = utils::Trim(input_text);
    if (trimmed.empty()) {
        return false;
    }

    auto strip_0x = [](const std::string& token) {
        if (token.size() > 2 && token[0] == '0' && (token[1] == 'x' || token[1] == 'X')) {
            return token.substr(2);
        }
        return token;
    };

    if (trimmed.find_first_of(" ,\t\r\n") == std::string::npos) {
        const std::string compact = strip_0x(trimmed);
        return utils::HexDecode(compact, bytes);
    }

    std::string normalized = trimmed;
    std::replace(normalized.begin(), normalized.end(), ',', ' ');
    std::istringstream stream(normalized);
    std::vector<uint8_t> parsed_bytes;
    std::string token;
    while (stream >> token) {
        const std::string hex = strip_0x(token);
        if (hex.empty() || hex.size() > 2) {
            return false;
        }
        std::string padded = hex;
        if (padded.size() == 1) {
            padded.insert(padded.begin(), '0');
        }
        std::vector<uint8_t> one_byte;
        if (!utils::HexDecode(padded, &one_byte) || one_byte.size() != 1) {
            return false;
        }
        parsed_bytes.push_back(one_byte.front());
    }
    if (parsed_bytes.empty()) {
        return false;
    }
    *bytes = std::move(parsed_bytes);
    return true;
}

bool TryAssembleArm64Instruction(uint64_t address,
                                 const std::string& input_text,
                                 std::vector<uint8_t>* bytes,
                                 std::string* error) {
    if (bytes == nullptr) {
        return false;
    }

    const std::vector<std::string> tokens = TokenizeInstructionText(input_text);
    if (tokens.empty()) {
        if (error != nullptr) {
            *error = "Instruction is empty.";
        }
        return false;
    }

    const auto fail = [error](const std::string& message) {
        if (error != nullptr) {
            *error = message;
        }
        return false;
    };

    if (tokens[0] == "nop" && tokens.size() == 1) {
        *bytes = EncodeArm64Word(0xD503201FU);
        return true;
    }

    if (tokens[0] == "ret") {
        int reg = 30;
        if (tokens.size() == 2) {
            if (!ParseArm64Register(tokens[1], &reg)) {
                return fail("Invalid ARM64 RET register.");
            }
        } else if (tokens.size() != 1) {
            return fail("Unsupported ARM64 RET syntax.");
        }
        *bytes = EncodeArm64Word(0xD65F0000U | (static_cast<uint32_t>(reg) << 5U));
        return true;
    }

    if (tokens[0] == "br" || tokens[0] == "blr") {
        if (tokens.size() != 2) {
            return fail("Unsupported ARM64 branch-register syntax.");
        }
        int reg = 0;
        if (!ParseArm64Register(tokens[1], &reg)) {
            return fail("Invalid ARM64 branch register.");
        }
        const uint32_t base = tokens[0] == "br" ? 0xD61F0000U : 0xD63F0000U;
        *bytes = EncodeArm64Word(base | (static_cast<uint32_t>(reg) << 5U));
        return true;
    }

    if (tokens[0] == "b" || tokens[0] == "bl") {
        if (tokens.size() != 2) {
            return fail("Unsupported ARM64 branch syntax.");
        }

        int64_t parsed_target = 0;
        if (!ParseSignedIntegerToken(tokens[1], &parsed_target)) {
            return fail("Invalid ARM64 branch target.");
        }

        uint64_t target_address = 0;
        if (tokens[1] == ".") {
            target_address = address;
        } else if (!tokens[1].empty() &&
                   (tokens[1].front() == '+' || tokens[1].front() == '-')) {
            target_address = static_cast<uint64_t>(
                static_cast<int64_t>(address) + parsed_target);
        } else {
            target_address = static_cast<uint64_t>(parsed_target);
        }

        const int64_t diff = static_cast<int64_t>(target_address) -
                             static_cast<int64_t>(address);
        if (diff % 4 != 0) {
            return fail("ARM64 branch target must be 4-byte aligned.");
        }

        const int64_t imm26 = diff / 4;
        constexpr int64_t kMinImm26 = -(1LL << 25);
        constexpr int64_t kMaxImm26 = (1LL << 25) - 1;
        if (imm26 < kMinImm26 || imm26 > kMaxImm26) {
            return fail("ARM64 branch target is out of range.");
        }

        const uint32_t base = tokens[0] == "b" ? 0x14000000U : 0x94000000U;
        const uint32_t encoded = base |
                                 (static_cast<uint32_t>(imm26) & 0x03FFFFFFU);
        *bytes = EncodeArm64Word(encoded);
        return true;
    }

    return fail("Unsupported ARM64 instruction. Use raw hex or ARM64 nop/ret/b/bl/br/blr.");
}

}  // namespace

MemoryInstructionInfo ReadMemoryInstruction(int pid, uint64_t address) {
    MemoryInstructionInfo info;
    if (pid <= 0 || address == 0) {
        return info;
    }

    InstructionDecodeConfig config;
    if (!ResolveInstructionDecodeConfig(&config)) {
        return info;
    }

    info.architecture = config.architecture;

    ProcessMemoryReader reader(pid);
    if (!reader.Read(address, config.read_size, &info.raw_bytes)) {
        return info;
    }

    csh handle = 0;
    if (cs_open(config.arch, config.mode, &handle) != CS_ERR_OK) {
        info.size = info.raw_bytes.size();
        info.text = FormatHexFallback(info.raw_bytes);
        info.is_valid = true;
        return info;
    }

    cs_option(handle, CS_OPT_DETAIL, CS_OPT_OFF);
    cs_insn* instruction = nullptr;
    const size_t count = cs_disasm(
        handle,
        info.raw_bytes.data(),
        info.raw_bytes.size(),
        address,
        1,
        &instruction);
    if (count > 0 && instruction != nullptr) {
        info.size = instruction[0].size;
        info.raw_bytes.resize(info.size);
        info.text = instruction[0].mnemonic;
        if (instruction[0].op_str[0] != '\0') {
            info.text += ' ';
            info.text += instruction[0].op_str;
        }
        info.is_valid = true;
    } else {
        info.size = info.raw_bytes.size();
        info.text = FormatHexFallback(info.raw_bytes);
        info.is_valid = true;
    }

    if (instruction != nullptr) {
        cs_free(instruction, count);
    }
    cs_close(&handle);
    return info;
}

InstructionPatchResultView PatchMemoryInstructionAtAddress(int pid,
                                                           uint64_t address,
                                                           const std::string& input_text) {
    const std::string trimmed_input = utils::Trim(input_text);
    if (trimmed_input.empty()) {
        throw std::runtime_error("Instruction is empty.");
    }

    const MemoryInstructionInfo current = ReadMemoryInstruction(pid, address);
    if (!current.is_valid || current.size == 0 || current.raw_bytes.empty()) {
        throw std::runtime_error("Failed to read current instruction.");
    }

    std::vector<uint8_t> patched_bytes;
    if (!TryParseHexBytes(trimmed_input, &patched_bytes)) {
        if (current.architecture != "aarch64") {
            throw std::runtime_error(
                "Text assembly patching is only supported on ARM64. Use raw hex bytes.");
        }

        std::string assembly_error;
        if (!TryAssembleArm64Instruction(
                address,
                trimmed_input,
                &patched_bytes,
                &assembly_error)) {
            throw std::runtime_error(
                assembly_error.empty() ? "Unsupported instruction patch input."
                                       : assembly_error);
        }
    }

    if (patched_bytes.size() != current.size) {
        throw std::runtime_error(
            "Patch size must match the current instruction size.");
    }

    std::string patch_error;
    if (!WriteInstructionBytesWithPtrace(pid, address, patched_bytes, &patch_error)) {
        throw std::runtime_error(
            patch_error.empty() ? "Failed to patch instruction bytes safely."
                                : patch_error);
    }

    const MemoryInstructionInfo patched = ReadMemoryInstruction(pid, address);

    InstructionPatchResultView result;
    result.address = address;
    result.architecture = current.architecture;
    result.instruction_size = current.size;
    result.before_bytes = current.raw_bytes;
    result.after_bytes = patched.is_valid && !patched.raw_bytes.empty()
                             ? patched.raw_bytes
                             : patched_bytes;
    result.instruction_text = patched.is_valid && !patched.text.empty()
                                  ? patched.text
                                  : FormatHexFallback(result.after_bytes);
    return result;
}

}  // namespace memory_tool
